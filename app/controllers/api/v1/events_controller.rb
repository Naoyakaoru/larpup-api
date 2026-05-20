module Api
  module V1
    class EventsController < ApplicationController
      skip_before_action :authenticate!, only: [ :index, :show ]

      before_action :set_event,          only: [ :show ]
      before_action :set_event_unscoped, only: [ :update, :destroy, :restore, :cancel, :join, :leave ]
      before_action :require_host!, only: [ :update, :destroy, :restore, :cancel ]

      def index
        events = Event.includes(script_version: [ { store: :addresses }, { script: { cover_image_attachment: :blob } } ]).includes(:host, :address, event_members: :user)
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
        render json: events.map { |e| EventSerializer.new(e, url_helper: method(:url_for)).as_json }
      end

      def show
        render json: EventSerializer.new(@event, detail: true, url_helper: method(:url_for)).as_json
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
          render json: EventSerializer.new(event, url_helper: method(:url_for)).as_json, status: :created
        else
          render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        permitted = has_members? ? location_only_params : event_params

        if @event.update(permitted)
          @event.sync_status
          render json: EventSerializer.new(@event, detail: true, url_helper: method(:url_for)).as_json
        else
          render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        if has_members?
          return render json: { error: "已有人申請，無法刪除" }, status: :unprocessable_entity
        end

        # BE-5: use soft_delete! so after_commit callbacks (audit log) fire normally
        @event.soft_delete!
        render json: { message: "Event deleted" }
      end

      def restore
        # BE-5: use restore! so after_commit callbacks (audit log) fire normally
        @event.restore!
        render json: EventSerializer.new(@event, detail: true, url_helper: method(:url_for)).as_json
      end

      def cancel
        if @event.cancelled? || @event.completed?
          return render json: { error: "活動已無法取消" }, status: :unprocessable_entity
        end

        @event.cancel!
        render json: EventSerializer.new(@event, detail: true, url_helper: method(:url_for)).as_json
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

        # BE-6: use row-level lock to prevent race condition (double-booking)
        @event.with_lock do
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
        # BE-4: preload event_members: :user so confirmed_count and members_data
        #        both walk in-memory associations (no extra DB queries)
        @event = Event.includes(:address, :host, event_members: :user, script_version: :script).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Event not found" }, status: :not_found
      end

      def set_event_unscoped
        @event = Event.unscoped.includes(:address, :host, script_version: :script).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Event not found" }, status: :not_found
      end

      def require_host!
        render json: { error: "Forbidden" }, status: :forbidden unless @event.host_id == current_user.id
      end

      # BE-1: delegate slot math to Event#remaining_slots (single source of truth)
      def slot_available_for?(effective_gender)
        slots = @event.remaining_slots
        if effective_gender == "male"
          slots[:male] > 0 || slots[:any] > 0
        else
          slots[:female] > 0 || slots[:any] > 0
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
