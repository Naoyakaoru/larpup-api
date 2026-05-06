module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate!, only: [ :register, :login ]

      def register
        user = User.new(register_params)
        if user.save
          token = JwtAuthenticatable.encode(user_id: user.id)
          render json: { token:, user: user_json(user) }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email]&.downcase)
        if user&.authenticate(params[:password])
          token = JwtAuthenticatable.encode(user_id: user.id)
          render json: { token:, user: user_json(user) }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def logout
        render json: { message: "Logged out" }
      end

      private

      def register_params
        params.permit(:email, :password, :password_confirmation, :nickname)
      end

      def user_json(user)
        { id: user.id, email: user.email, nickname: user.nickname, is_admin: user.is_admin }
      end
    end
  end
end
