class ScriptSerializer
  def initialize(script, url_helper: nil)
    @script = script
    @url_helper = url_helper
  end

  def as_json(*)
    {
      id: @script.id,
      title: @script.title,
      genres: @script.genre_labels,
      difficulty: @script.difficulty,
      male_slots: @script.male_slots,
      female_slots: @script.female_slots,
      any_slots: @script.any_slots,
      total_slots: @script.total_slots,
      description: @script.description,
      status: @script.status,
      duration: @script.duration&.to_f,
      cover_image_url: cover_image_url
    }
  end

  private

  def cover_image_url
    return nil unless @script.cover_image.attached?
    @url_helper&.call(@script.cover_image)
  end
end
