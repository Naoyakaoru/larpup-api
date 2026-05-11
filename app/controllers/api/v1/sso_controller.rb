require "net/http"
require "json"

module Api
  module V1
    class SsoController < ApplicationController
      skip_before_action :authenticate!
      before_action :try_authenticate

      private

      def try_authenticate
        token = request.headers["Authorization"]&.split(" ")&.last
        return unless token

        payload = JwtAuthenticatable.decode(token)
        @current_user = User.find_by(id: payload&.dig("user_id"))
      end

      public

      # POST /api/v1/auth/sso/google
      # Body: { id_token: "..." }
      def google
        id_token = params[:id_token]
        return render json: { error: "Missing id_token" }, status: :bad_request if id_token.blank?

        profile = verify_google_token(id_token)
        return render json: { error: "Invalid Google token" }, status: :unauthorized if profile.nil?

        handle_sso_login(
          uid_field: :google_uid,
          uid:       profile["sub"],
          email:     profile["email"],
          nickname:  profile["name"]
        )
      end

      # POST /api/v1/auth/sso/line
      # Body: { code: "...", redirect_uri: "..." }
      def line
        code         = params[:code]
        redirect_uri = params[:redirect_uri]
        return render json: { error: "Missing code" }, status: :bad_request if code.blank?

        profile = exchange_line_code(code, redirect_uri)
        return render json: { error: "LINE login failed" }, status: :unauthorized if profile.nil?

        # Reject accounts where LINE did not provide an email
        if profile[:email].blank?
          return render json: {
            error: "請在 LINE 設定中允許分享 Email，或使用 Google 登入"
          }, status: :unprocessable_entity
        end

        handle_sso_login(
          uid_field: :line_uid,
          uid:       profile[:uid],
          email:     profile[:email],
          nickname:  profile[:nickname]
        )
      end

      # POST /api/v1/auth/sso/register
      # Body: { temp_token: "...", gender: "male"|"female", nickname: "..." }
      def register
        payload = JwtAuthenticatable.decode(params[:temp_token])

        if payload.nil? || payload["type"] != "sso_pending"
          return render json: { error: "Invalid or expired token" }, status: :unauthorized
        end

        uid_field = payload["uid_field"].to_sym
        uid       = payload["uid"]
        email     = payload["email"]
        nickname  = params[:nickname].presence || payload["nickname"]
        gender    = params[:gender]

        user = User.new(email: email, nickname: nickname, gender: gender)
        user[uid_field] = uid

        if user.save
          token = JwtAuthenticatable.encode(user_id: user.id)
          render json: { token:, user: user_json(user) }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      # Verify Google id_token via Google's tokeninfo endpoint
      def verify_google_token(id_token)
        uri      = URI("https://oauth2.googleapis.com/tokeninfo?id_token=#{URI.encode_www_form_component(id_token)}")
        response = Net::HTTP.get_response(uri)
        return nil unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)
        # Verify the token is issued for our app
        return nil if data["aud"] != ENV.fetch("GOOGLE_CLIENT_ID", nil)
        return nil if data["sub"].blank? || data["email"].blank?

        data
      rescue StandardError
        nil
      end

      # Exchange LINE auth code for user profile
      def exchange_line_code(code, redirect_uri)
        # Step 1: exchange code for access_token + id_token
        token_uri  = URI("https://api.line.me/oauth2/v2.1/token")
        token_form = URI.encode_www_form(
          grant_type:    "authorization_code",
          code:          code,
          redirect_uri:  redirect_uri,
          client_id:     ENV.fetch("LINE_CHANNEL_ID", nil),
          client_secret: ENV.fetch("LINE_CHANNEL_SECRET", nil)
        )

        token_res = Net::HTTP.post(
          token_uri,
          token_form,
          "Content-Type" => "application/x-www-form-urlencoded"
        )
        return nil unless token_res.is_a?(Net::HTTPSuccess)

        token_data   = JSON.parse(token_res.body)
        access_token = token_data["access_token"]
        return nil if access_token.blank?

        # Step 2: get user profile
        profile_uri = URI("https://api.line.me/v2/profile")
        profile_req = Net::HTTP::Get.new(profile_uri)
        profile_req["Authorization"] = "Bearer #{access_token}"

        profile_res = Net::HTTP.start(profile_uri.host, profile_uri.port, use_ssl: true) do |http|
          http.request(profile_req)
        end
        return nil unless profile_res.is_a?(Net::HTTPSuccess)

        profile_data = JSON.parse(profile_res.body)
        uid          = profile_data["userId"]
        display_name = profile_data["displayName"]
        return nil if uid.blank?

        # Step 3: get email from id_token claims (requires email scope approval from LINE)
        # Returns nil if LINE did not provide email — caller will reject the login
        email = extract_line_email(token_data["id_token"])

        { uid: uid, nickname: display_name, email: email }
      rescue StandardError
        nil
      end

      # Decode LINE id_token (JWT) to extract email claim without signature verification
      # (Signature is already trusted because we just received it from LINE's server)
      def extract_line_email(id_token)
        return nil if id_token.blank?

        _header, payload_b64, _sig = id_token.split(".")
        return nil if payload_b64.blank?

        padded  = payload_b64 + "=" * ((4 - payload_b64.length % 4) % 4)
        decoded = JSON.parse(Base64.urlsafe_decode64(padded))
        decoded["email"].presence
      rescue StandardError
        nil
      end

      # Shared SSO login logic
      def handle_sso_login(uid_field:, uid:, email:, nickname:)
        if @current_user
          # Binding mode
          if User.exists?(uid_field => uid) && @current_user[uid_field] != uid
            return render json: { error: "此社群帳號已經被其他會員綁定過了" }, status: :conflict
          end
          
          @current_user.update_column(uid_field, uid)
          token = JwtAuthenticatable.encode(user_id: @current_user.id)
          return render json: { token:, user: user_json(@current_user) }, status: :ok
        end

        # 1. Find by uid
        user = User.find_by(uid_field => uid)

        # 2. Prevent unverified auto-binding (Account Takeover Risk)
        if user.nil? && email.present?
          canonical = User.canonicalize_email(email)
          if User.exists?(canonical_email: canonical)
            return render json: { error: "此 Email 已被註冊，請使用原本的方式登入（或至會員中心綁定帳號）" }, status: :conflict
          end
        end

        if user
          # Existing user: issue JWT
          token = JwtAuthenticatable.encode(user_id: user.id)
          render json: { token:, user: user_json(user) }, status: :ok
        else
          # New user: issue short-lived temp_token
          temp_token = JwtAuthenticatable.encode(
            type:      "sso_pending",
            uid_field: uid_field.to_s,
            uid:       uid,
            email:     email,
            nickname:  nickname,
            exp:       5.minutes.from_now.to_i
          )
          render json: { temp_token:, email:, nickname: }, status: :accepted
        end
      end

      def user_json(user)
        {
          id:                 user.id,
          handle:             user.handle,
          email:              user.email,
          nickname:           user.nickname,
          gender:             user.gender,
          avatar_url:         user.avatar.attached? ? url_for(user.avatar) : nil,
          is_admin:           user.is_admin,
          show_hosted_events: user.show_hosted_events,
          has_google:         user.google_uid.present?,
          has_line:           user.line_uid.present?
        }
      end
    end
  end
end
