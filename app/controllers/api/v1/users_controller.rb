module Api
  module V1
    class UsersController < ApplicationController
      skip_before_action :authenticate!, only: [ :show ]
      before_action :require_admin!, only: [ :search ]

      def me
        render json: user_json(current_user)
      end

      def show
        user = User.find_by!(handle: params[:handle])
        render json: public_profile_json(user)
      end

      def update
        if current_user.update(user_params)
          render json: user_json(current_user)
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def stores
        owned = current_user.owned_stores.order(:name).map do |s|
          { id: s.id, name: s.name, status: s.status, role: "owner" }
        end
        render json: owned
      end

      def search
        q = params[:q].to_s.strip
        users = q.length >= 1 ? User.where("nickname ILIKE :q OR handle ILIKE :q", q: "%#{q}%").limit(10) : []
        render json: users.map { |u| user_json(u) }
      end

      def events
        scope = params[:include_past] == "true" ? Event.unscoped.where(deleted_at: nil) : Event.where("scheduled_at >= ?", Time.current)
        hosted = current_user.hosted_events.merge(scope).order(scheduled_at: :asc).includes(:address, :host, script_version: :script, event_members: :user)
        joined = current_user.joined_events.merge(scope).order(scheduled_at: :asc).includes(:address, :host, script_version: :script, event_members: :user)
        render json: {
          hosted: hosted.map { |e| EventSerializer.new(e, url_helper: method(:url_for)).as_json },
          joined: joined.map { |e| EventSerializer.new(e, url_helper: method(:url_for)).as_json }
        }
      end

      private

      def user_params
        params.permit(:nickname, :handle, :avatar, :password, :password_confirmation, :show_hosted_events)
      end

      def user_json(user)
        {
          id: user.id,
          handle: user.handle,
          email: user.email,
          nickname: user.nickname,
          gender: user.gender,
          avatar_url: user.avatar.attached? ? "https://cdn.larpup.tw/#{user.avatar.key}" : nil,
          is_admin: user.is_admin,
          show_hosted_events: user.show_hosted_events,
          has_google: user.google_uid.present?,
          has_line: user.line_uid.present?
        }
      end

      def public_profile_json(user)
        json = {
          id: user.id,
          handle: user.handle,
          nickname: user.nickname,
          gender: user.gender,
          avatar_url: user.avatar.attached? ? "https://cdn.larpup.tw/#{user.avatar.key}" : nil
        }
        if user.show_hosted_events
          hosted = user.hosted_events.where(status: [ :recruiting, :full ]).where("scheduled_at >= ?", Time.current).order(scheduled_at: :asc).includes(:address, :host, script_version: :script, event_members: :user)
          json[:hosted_events] = hosted.map { |e| EventSerializer.new(e, url_helper: method(:url_for)).as_json }
        end
        json
      end
    end
  end
end
