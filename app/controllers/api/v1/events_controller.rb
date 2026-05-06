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
          if ActiveModel::Type::Boolean.new.cast(params[:host_in_game])
            event.event_members.create!(
              user: current_user,
              status: :confirmed,
              cross_gender: ActiveModel::Type::Boolean.new.cast(params[:host_cross_gender])
            )
          end
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
        if @event.event_members.exists?
          return render json: { error: "已有人申請，無法刪除" }, status: :unprocessable_entity
        end

        @event.destroy!
        render json: { message: "Event deleted" }
      end

      def join
        if @event.host_id == current_user.id
          return render json: { error: "You are the host" }, status: :unprocessable_entity
        end

        if @event.cancelled?
          return render json: { error: "Event is cancelled" }, status: :unprocessable_entity
        end

        member = @event.event_members.find_or_initialize_by(user_id: current_user.id)

        if member.persisted?
          return render json: { error: "Already joined" }, status: :unprocessable_entity
        end

        cross_gender = params[:cross_gender] && @event.allow_cross_gender
        effective_gender = cross_gender ? (current_user.gender == "male" ? "female" : "male") : current_user.gender

        unless slot_available_for?(effective_gender)
          return render json: { error: "沒有符合性別的空位" }, status: :unprocessable_entity
        end

        member.assign_attributes(status: :pending, cross_gender: cross_gender)
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

      def slot_available_for?(effective_gender)
        script = @event.script
        confirmed = @event.event_members.confirmed.includes(:user)

        male_filled = @event.offline_male
        female_filled = @event.offline_female
        any_filled = 0

        confirmed.each do |m|
          eg = m.cross_gender ? (m.user.gender == "male" ? "female" : "male") : m.user.gender
          if eg == "male" && male_filled < script.male_slots
            male_filled += 1
          elsif eg == "female" && female_filled < script.female_slots
            female_filled += 1
          else
            any_filled += 1
          end
        end

        remaining_male = [ script.male_slots - male_filled, 0 ].max
        remaining_female = [ script.female_slots - female_filled, 0 ].max
        remaining_any = [ script.any_slots - any_filled, 0 ].max

        if effective_gender == "male"
          remaining_male > 0 || remaining_any > 0
        else
          remaining_female > 0 || remaining_any > 0
        end
      end

      def event_params
        params.permit(:script_id, :scheduled_at, :location, :status, :allow_cross_gender, :offline_male, :offline_female)
      end

      def event_json(event, detail: false)
        json = {
          id: event.id,
          script: { id: event.script.id, title: event.script.title, total_slots: event.script.total_slots,
                    male_slots: event.script.male_slots, female_slots: event.script.female_slots, any_slots: event.script.any_slots,
                    difficulty: event.script.difficulty, genres: event.script.genres },
          host: { id: event.host.id, nickname: event.host.nickname },
          allow_cross_gender: event.allow_cross_gender,
          offline_male: event.offline_male,
          offline_female: event.offline_female,
          scheduled_at: event.scheduled_at,
          location: event.location,
          status: event.status,
          confirmed_count: event.confirmed_count,
          available_slots: event.available_slots
        }

        if detail
          json[:members] = event.event_members.includes(:user).map do |m|
            { id: m.id, user: { id: m.user.id, nickname: m.user.nickname, gender: m.user.gender }, status: m.status, cross_gender: m.cross_gender }
          end
        end

        json
      end
    end
  end
end
