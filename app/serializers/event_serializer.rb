class EventSerializer
  def initialize(event, detail: false, url_helper: nil)
    @event = event
    @detail = detail
    @url_helper = url_helper
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
      address: @event.address ? AddressSerializer.new(@event.address).as_json : nil,
      status: @event.status,
      script_version_id: @event.script_version_id,
      confirmed_count: @event.confirmed_count,
      available_slots: @event.available_slots,
      slot_parts: slot_parts_string,
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
      genres: s.genres,
      duration: v.effective_duration,
      price: v.effective_price,
      store: v.store ? { id: v.store.id, name: v.store.name } : nil,
      version_name: v.version_name,
      cover_image_url: (s.cover_image.attached? && @url_helper) ? @url_helper.call(s.cover_image) : nil
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

  def slot_parts_string
    return "" if @event.status == "full" || @event.status == "completed" || @event.status == "cancelled"

    script = @event.script_version.script
    # For performance, only do this if needed, or if members are preloaded.
    # The ideal way is to always preload event_members when serializing collections.
    confirmed = @event.event_members.select { |m| m.status == "confirmed" }

    male_filled = @event.offline_male
    female_filled = @event.offline_female
    any_filled = 0

    confirmed.each do |m|
      # Since we might not have user eager loaded in all collections, try to safely get gender
      user_gender = m.user&.gender rescue "male" 
      eg = m.cross_gender ? (user_gender == "male" ? "female" : "male") : user_gender
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

    parts = []
    parts << "#{remaining_male}男" if remaining_male > 0
    parts << "#{remaining_female}女" if remaining_female > 0
    parts << "#{remaining_any}不限" if remaining_any > 0
    parts.join("")
  end
end
