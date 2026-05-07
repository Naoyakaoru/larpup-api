class EventSerializer
  def initialize(event, detail: false)
    @event = event
    @detail = detail
  end

  def as_json(*)
    json = {
      id: @event.id,
      script: script_data,
      host: { id: @event.host.id, handle: @event.host.handle, nickname: @event.host.nickname },
      allow_cross_gender: @event.allow_cross_gender,
      offline_male: @event.offline_male,
      offline_female: @event.offline_female,
      scheduled_at: @event.scheduled_at,
      location: @event.location,
      status: @event.status,
      script_version_id: @event.script_version_id,
      confirmed_count: @event.confirmed_count,
      available_slots: @event.available_slots,
      deleted_at: @event.deleted_at
    }
    if @detail
      json[:members] = members_data
      json[:audit_logs] = audit_logs_data
    end
    json
  end

  private

  def script_data
    v = @event.script_version
    s = v.script
    {
      id: s.id,
      title: s.title,
      total_slots: s.total_slots,
      male_slots: s.male_slots,
      female_slots: s.female_slots,
      any_slots: s.any_slots,
      difficulty: s.difficulty,
      difficulty_label: s.difficulty_label,
      genres: s.genre_labels,
      duration: (v.duration_override || s.duration)&.to_f,
      price: v.price,
      store: v.store ? { id: v.store.id, name: v.store.name } : nil,
      version_name: v.version_name
    }
  end

  def members_data
    @event.event_members.includes(:user).map do |m|
      {
        id: m.id,
        user: { id: m.user.id, handle: m.user.handle, nickname: m.user.nickname, gender: m.user.gender },
        status: m.status,
        cross_gender: m.cross_gender,
        applied_at: m.created_at,
        confirmed_at: m.confirmed_at,
        rejected_at: m.rejected_at,
        leave_requested_at: m.leave_requested_at,
        cancelled_at: m.cancelled_at
      }
    end
  end

  def audit_logs_data
    @event.audit_logs.includes(:user).order(created_at: :desc).map do |log|
      {
        action: log.action,
        metadata: log.metadata,
        user: { id: log.user.id, nickname: log.user.nickname },
        created_at: log.created_at
      }
    end
  end
end
