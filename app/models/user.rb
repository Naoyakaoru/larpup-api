class User < ApplicationRecord
  has_secure_password

  has_one_attached :avatar

  has_many :hosted_events, class_name: "Event", foreign_key: :host_id, dependent: :destroy
  has_many :event_members, dependent: :destroy
  has_many :joined_events, through: :event_members, source: :event

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :nickname, presence: true
  validates :password, length: { minimum: 6 }, allow_nil: true

  before_save { self.email = email.downcase }
end
