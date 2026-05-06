class Store < ApplicationRecord
  has_many :script_versions, dependent: :destroy
  has_many :scripts, through: :script_versions

  enum :status, { active: "active", inactive: "inactive" }, default: :active

  validates :name, presence: true
end
