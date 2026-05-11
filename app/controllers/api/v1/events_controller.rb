module Api
  module V1
    class EventsController < ApplicationController
      skip_before_action :authenticate!, only: [ :index, :show ]

      before_action :set_event, only: [ :show, :update, :destroy, :restore, :cancel, :join, :leave ]
      before_action :require_host!, only: [ :update, :destroy, :restore, :cancel ]

      def index
        events = Event.includes(script_version: [ { store: :addresses }, { script: { cover_image_attachment: :blob } } ]).includes(:host, :address)
        events = events.where(status: params[:status]) if params[:status].present?
        if params[:script_id].present?
          version_ids = ScriptVersion.where(script_id: params[:script_id]).pluck(:id)
          events = events.where(script_version_id: version_ids)
        end
        if params[:date].present?
          events = events.where("scheduled_at >= ?", Date.parse(params[:date]))
        else
          events = events.where("scheduled_at >= ?", Time.current)
        end
        events = events.order(scheduled_at: :asc)
        render json: events.map { |e| EventSerializer.new(e).as_json }
      end

      def show
        render json: EventSerializer.new(@event, detail: true).as_json
      end

      def create
        event = current_user.hosted_events.build(event_params)
        if event.script_version_id.nil? && params[:script_id].present?
          script = Script.find_by(id: params[:script_id])
          event.script_version = script&.script_versions&.find_by(store_id: nil)
        end
        if event.save
          if ActiveModel::Type::Boolean.new.cast(params[:host_in_game])
            event.event_members.create!(
              user: current_user,
              status: :confirmed,
              confirmed_at: Time.current,
              cross_gender: ActiveModel::Type::Boolean.new.cast(params[:host_cross_gender])
            )
          end
          event.sync_status
          render json: EventSerializer.new(event).as_json, status: :created
        else
          render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        permitted = has_members? ? location_only_params : event_params

        old_location = @event.location
        old_address_id = @event.address_id
        old_address_name = @event.address&.name
        if @event.update(permitted)
          if has_members? && (@event.location != old_location || @event.address_id != old_address_id)
            new_address_name = @event.address_id ? Address.find_by(id: @event.address_id)&.name : nil
            AuditLog.create!(
              auditable: @event,
              user: current_user,
              action: "location_changed",
              metadata: {
                from: old_address_name || old_location,
                to: new_address_name || @event.location
              }
            )
          end
          @event.sync_status
          render json: EventSerializer.new(@event, detail: true).as_json
        else
          render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        if has_members?
          return render json: { error: "已有人申請，無法刪除" }, status: :unprocessable_entity
        end

        @event.update_column(:deleted_at, Time.current)
        render json: { message: "Event deleted" }
      end

      def restore
        @event.update_column(:deleted_at, nil)
        render json: EventSerializer.new(@event, detail: true).as_json
      end

      def cancel
        if @event.cancelled? || @event.completed?
          return render json: { error: "活動已無法取消" }, status: :unprocessable_entity
        end

        @event.cancel!
        render json: EventSerializer.new(@event, detail: true).as_json
      end

      def join
        if @event.host_id == current_user.id
          return render json: { error: "You are the host" }, status: :unprocessable_entity
        end

        if @event.cancelled?
          return render json: { error: "Event is cancelled" }, status: :unprocessable_entity
        end

        member = @event.event_members.find_by(user_id: current_user.id)

        if member&.active_member?
          return render json: { error: "Already joined" }, status: :unprocessable_entity
        end

        if member&.rejected?
          return render json: { error: "已被拒絕，無法重新申請" }, status: :unprocessable_entity
        end

        cross_gender = params[:cross_gender].present? && @event.allow_cross_gender
        effective_gender = cross_gender ? (current_user.gender == "male" ? "female" : "male") : current_user.gender

        unless slot_available_for?(effective_gender)
          return render json: { error: "沒有符合性別的空位" }, status: :unprocessable_entity
        end

        if member&.cancelled?
          member.update!(cross_gender: cross_gender)
          member.reapply!
          render json: { message: "Join request sent" }, status: :created
        else
          member = @event.event_members.build(user: current_user, status: :pending, cross_gender: cross_gender)
          if member.save
            render json: { message: "Join request sent" }, status: :created
          else
            render json: { errors: member.errors.full_messages }, status: :unprocessable_entity
          end
        end
      end

      def leave
        member = @event.event_members.find_by(user_id: current_user.id)
        return render json: { error: "Not a member" }, status: :not_found unless member

        if member.confirmed?
          member.request_leave!
          render json: { message: "Leave request sent, waiting for host approval" }
        elsif member.pending?
          member.cancel!
          render json: { message: "Left event" }
        else
          render json: { error: "Cannot leave in current status" }, status: :unprocessable_entity
        end
      end

      private

      def set_event
        @event = Event.unscoped.includes(:address, :host, script_version: :script).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Event not found" }, status: :not_found
      end

      def require_host!
        render json: { error: "Forbidden" }, status: :forbidden unless @event.host_id == current_user.id
      end

      def slot_available_for?(effective_gender)
        script = @event.script_version.script
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

      def has_members?
        @_has_members ||= @event.event_members.where.not(user_id: @event.host_id).exists?
      end

      def event_params
        params.permit(:script_version_id, :scheduled_at, :location, :address_id, :status, :allow_cross_gender, :offline_male, :offline_female)
      end

      def location_only_params
        params.permit(:location, :address_id, :offline_male, :offline_female, :allow_cross_gender)
      end
    end
  end
end
