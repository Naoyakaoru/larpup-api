module Api
  module V1
    class EventMembersController < ApplicationController
      before_action :set_event
      before_action :require_host!

      def index
        members = @event.event_members.includes(:user)
        render json: members.map { |m| member_json(m) }
      end

      def update
        member = @event.event_members.find(params[:id])
        new_status = params[:status]

        unless valid_transition?(member, new_status)
          return render json: { error: "Invalid status transition" }, status: :unprocessable_entity
        end

        timestamp_field = "#{new_status}_at"
        attrs = { status: new_status }
        attrs[timestamp_field] = Time.current if member.class.column_names.include?(timestamp_field)

        if member.update(attrs)
          @event.sync_status if member.confirmed?
          render json: member_json(member)
        else
          render json: { errors: member.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Member not found" }, status: :not_found
      end

      private

      def set_event
        @event = Event.find(params[:event_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Event not found" }, status: :not_found
      end

      def require_host!
        render json: { error: "Forbidden" }, status: :forbidden unless @event.host_id == current_user.id
      end

      def valid_transition?(member, new_status)
        case member.status
        when "pending"         then %w[confirmed rejected].include?(new_status)
        when "leave_requested" then %w[cancelled].include?(new_status)
        else false
        end
      end

      def member_json(member)
        { id: member.id, user: { id: member.user.id, nickname: member.user.nickname }, status: member.status }
      end
    end
  end
end
