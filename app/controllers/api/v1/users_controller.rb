module Api
  module V1
    class UsersController < ApplicationController
      def me
        render json: user_json(current_user)
      end

      def update
        if current_user.update(user_params)
          render json: user_json(current_user)
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def events
        hosted = current_user.hosted_events.includes(:script)
        joined = current_user.joined_events.includes(:script)
        render json: {
          hosted: hosted.map { |e| event_json(e) },
          joined: joined.map { |e| event_json(e) }
        }
      end

      private

      def user_params
        params.permit(:nickname, :avatar, :password, :password_confirmation)
      end

      def user_json(user)
        {
          id: user.id,
          email: user.email,
          nickname: user.nickname,
          gender: user.gender,
          avatar_url: user.avatar.attached? ? url_for(user.avatar) : nil,
          is_admin: user.is_admin
        }
      end

      def event_json(event)
        {
          id: event.id,
          script: { id: event.script.id, title: event.script.title },
          scheduled_at: event.scheduled_at,
          location: event.location,
          status: event.status
        }
      end
    end
  end
end
