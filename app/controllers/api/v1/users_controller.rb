module Api
  module V1
    class UsersController < ApplicationController
      skip_before_action :authenticate!, only: [ :show ]

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

      def events
        scope = params[:include_past] == "true" ? Event.unscoped.where(deleted_at: nil) : Event.where("scheduled_at >= ?", Time.current)
        hosted = current_user.hosted_events.merge(scope).order(scheduled_at: :asc).includes(script_version: :script)
        joined = current_user.joined_events.merge(scope).order(scheduled_at: :asc).includes(script_version: :script)
        render json: {
          hosted: hosted.map { |e| event_json(e) },
          joined: joined.map { |e| event_json(e) }
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
          avatar_url: user.avatar.attached? ? url_for(user.avatar) : nil,
          is_admin: user.is_admin,
          show_hosted_events: user.show_hosted_events
        }
      end

      def public_profile_json(user)
        json = {
          id: user.id,
          handle: user.handle,
          nickname: user.nickname,
          gender: user.gender,
          avatar_url: user.avatar.attached? ? url_for(user.avatar) : nil
        }
        if user.show_hosted_events
          hosted = user.hosted_events.where(status: [ :recruiting, :full ]).where("scheduled_at >= ?", Time.current).order(scheduled_at: :asc).includes(script_version: :script)
          json[:hosted_events] = hosted.map { |e| event_json(e) }
        end
        json
      end

      def event_json(event)
        {
          id: event.id,
          script: { id: event.script_version.script.id, title: event.script_version.script.title },
          scheduled_at: event.scheduled_at,
          location: event.location,
          status: event.status
        }
      end
    end
  end
end
