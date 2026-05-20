class ScriptSerializer
  def initialize(script, url_helper: nil, include_metadata: false)
    @script = script
    @url_helper = url_helper
    @include_metadata = include_metadata
  end

  def as_json(*)
    {
      id: @script.id,
      title: @script.title,
      genres: @script.genres,
      difficulty: @script.difficulty,
      male_slots: @script.male_slots,
      female_slots: @script.female_slots,
      any_slots: @script.any_slots,
      total_slots: @script.total_slots,
      description: @script.description,
      publisher: @script.publisher,
      status: @script.status,
      duration: @script.duration,
      cover_image_url: cover_image_url,
      qiandao_cover_id: @script.metadata&.dig("qiandao_cover_id"),
      deleted_at: @script.deleted_at
    }
    hash[:metadata] = @script.metadata if @include_metadata
    hash
  end

  private

  def cover_image_url
    return nil unless @script.cover_image.attached?
    "https://cdn.larpup.tw/#{@script.cover_image.key}"
  end
end
