module Api
  module V1
    class EventsController < ApplicationController
      skip_before_action :authenticate!, only: [ :index, :show ]

      before_action :set_event, only: [ :show, :update, :destroy, :join, :leave ]
      before_action :require_host!, only: [ :update, :destroy ]

      def index
        events = Event.includes(:script, :host).all
        events = events.where(status: params[:status]) if params[:status].present?
        events = events.where(script_id: params[:script_id]) if params[:script_id].present?
        events = events.where("scheduled_at >= ?", Date.parse(params[:date])) if params[:date].present?
        render json: events.map { |e| event_json(e) }
      end

      def show
        render json: event_json(@event, detail: true)
      end

      def create
        event = current_user.hosted_events.build(event_params)
        if event.save
          render json: event_json(event), status: :created
        else
          render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @event.update(event_params)
          render json: event_json(@event)
        else
          render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @event.cancelled!
        render json: { message: "Event cancelled" }
      end

      def join
        if @event.cancelled?
          return render json: { error: "Event is cancelled" }, status: :unprocessable_entity
        end

        member = @event.event_members.find_or_initialize_by(user_id: current_user.id)

        if member.persisted?
          return render json: { error: "Already joined" }, status: :unprocessable_entity
        end

        member.status = :pending
        if member.save
          render json: { message: "Join request sent" }, status: :created
        else
          render json: { errors: member.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def leave
        member = @event.event_members.find_by(user_id: current_user.id)
        return render json: { error: "Not a member" }, status: :not_found unless member

        if member.confirmed?
          member.leave_requested!
          render json: { message: "Leave request sent, waiting for host approval" }
        elsif member.pending?
          member.cancelled!
          render json: { message: "Left event" }
        else
          render json: { error: "Cannot leave in current status" }, status: :unprocessable_entity
        end
      end

      private

      def set_event
        @event = Event.includes(:script, :host).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Event not found" }, status: :not_found
      end

      def require_host!
        render json: { error: "Forbidden" }, status: :forbidden unless @event.host_id == current_user.id
      end

      def event_params
        params.permit(:script_id, :scheduled_at, :location, :status)
      end

      def event_json(event, detail: false)
        json = {
          id: event.id,
          script: { id: event.script.id, title: event.script.title, total_slots: event.script.total_slots },
          host: { id: event.host.id, nickname: event.host.nickname },
          scheduled_at: event.scheduled_at,
          location: event.location,
          status: event.status,
          confirmed_count: event.confirmed_count,
          available_slots: event.available_slots
        }

        if detail
          json[:members] = event.event_members.includes(:user).map do |m|
            { id: m.id, user: { id: m.user.id, nickname: m.user.nickname }, status: m.status }
          end
        end

        json
      end
    end
  end
end
