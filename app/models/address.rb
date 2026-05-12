class Address < ApplicationRecord
  enum :region, {
    taipei_city: "台北市",
    new_taipei:  "新北市",
    taichung:    "台中市",
    kaohsiung:   "高雄市"
  }

  has_many :audit_logs, as: :auditable, dependent: :destroy
  has_many :store_addresses, dependent: :destroy
  has_many :stores, through: :store_addresses
  has_many :script_version_addresses, dependent: :destroy
  has_many :script_versions, through: :script_version_addresses

  GOOGLE_MAPS_URL_PATTERN = %r{\Ahttps://(maps\.google\.com|www\.google\.com/maps|goo\.gl/maps|maps\.app\.goo\.gl)/}i

  validates :name, presence: true, uniqueness: true
  validates :region, presence: true
  validates :map_url, format: { with: GOOGLE_MAPS_URL_PATTERN, message: "必須是 Google Maps 連結" }, allow_blank: true

  scope :active, -> { where(deleted_at: nil) }

  def soft_delete!(user:)
    transaction do
      update_column(:deleted_at, Time.current)
      AuditLog.create!(
        auditable: self,
        user: user,
        action: "deleted",
        metadata: {}
      )
    end
  end
end
