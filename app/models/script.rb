class Script < ApplicationRecord
  has_one_attached :cover_image

  has_many :script_versions, dependent: :destroy
  has_many :events, through: :script_versions

  GENRES = {
    mystery: 0,
    restoration: 1,
    horror: 2,
    romance: 3,
    comedy: 4,
    mechanism: 5,
    faction: 6,
    ancient: 7,
    modern: 8
  }.freeze

  GENRE_LABELS = {
    mystery: "推理",
    restoration: "還原",
    horror: "恐怖",
    romance: "情感",
    comedy: "歡樂",
    mechanism: "機制",
    faction: "陣營",
    ancient: "古風",
    modern: "現代"
  }.freeze

  DIFFICULTY_LABELS = { easy: "入門", medium: "進階", hard: "燒腦" }.freeze

  enum :difficulty, { easy: 0, medium: 1, hard: 2 }
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, default: :approved

  def difficulty_label
    DIFFICULTY_LABELS[difficulty.to_sym]
  end

  validates :title, presence: true
  validates :difficulty, presence: true
  validates :male_slots, :female_slots, :any_slots, numericality: { greater_than_or_equal_to: 0 }
  validate :genres_must_be_valid
  validate :at_least_one_slot

  def total_slots
    male_slots.to_i + female_slots.to_i + any_slots.to_i
  end

  def genre_labels
    (genres || []).map { |g| GENRE_LABELS[GENRES.key(g)] }
  end

  private

  def genres_must_be_valid
    return if genres.blank?

    invalid = genres - GENRES.values
    errors.add(:genres, "contains invalid values") if invalid.any?
  end

  def at_least_one_slot
    errors.add(:base, "must have at least one slot") if total_slots < 1
  end
end
