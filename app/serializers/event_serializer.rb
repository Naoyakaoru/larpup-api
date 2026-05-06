class EventSerializer
  def initialize(event, detail: false)
    @event = event
    @detail = detail
  end

  def as_json(*)
    json = {
      id: @event.id,
      script: script_data,
      host: { id: @event.host.id, nickname: @event.host.nickname },
      allow_cross_gender: @event.allow_cross_gender,
      offline_male: @event.offline_male,
      offline_female: @event.offline_female,
      scheduled_at: @event.scheduled_at,
      location: @event.location,
      status: @event.status,
      confirmed_count: @event.confirmed_count,
      available_slots: @event.available_slots
    }
    json[:members] = members_data if @detail
    json
  end

  private

  def script_data
    s = @event.script
    {
      id: s.id,
      title: s.title,
      total_slots: s.total_slots,
      male_slots: s.male_slots,
      female_slots: s.female_slots,
      any_slots: s.any_slots,
      difficulty: s.difficulty,
      difficulty_label: s.difficulty_label,
      genres: s.genre_labels
    }
  end

  def members_data
    @event.event_members.includes(:user).map do |m|
      {
        id: m.id,
        user: { id: m.user.id, nickname: m.user.nickname, gender: m.user.gender },
        status: m.status,
        cross_gender: m.cross_gender
      }
    end
  end
end
