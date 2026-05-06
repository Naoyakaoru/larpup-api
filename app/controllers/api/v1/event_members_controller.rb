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

        aasm_event = AASM_EVENT_MAP[new_status]
        unless aasm_event && member.aasm.may_fire_event?(aasm_event)
          return render json: { error: "Invalid status transition" }, status: :unprocessable_entity
        end

        member.public_send(:"#{aasm_event}!")
        @event.sync_status
        render json: member_json(member)
      rescue AASM::InvalidTransition
        render json: { error: "Invalid status transition" }, status: :unprocessable_entity
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

      AASM_EVENT_MAP = {
        "confirmed"      => :confirm,
        "rejected"       => :reject,
        "cancelled"      => :cancel
      }.freeze

      def member_json(member)
        { id: member.id, user: { id: member.user.id, nickname: member.user.nickname }, status: member.status }
      end
    end
  end
end
