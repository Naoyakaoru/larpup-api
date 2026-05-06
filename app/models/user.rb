class User < ApplicationRecord
  has_secure_password

  has_one_attached :avatar

  has_many :hosted_events, class_name: "Event", foreign_key: :host_id, dependent: :destroy
  has_many :event_members, dependent: :destroy
  has_many :joined_events, through: :event_members, source: :event

  GENDERS = %w[male female].freeze
  HANDLE_FORMAT = /\A[a-z0-9_]{3,30}\z/

  before_validation :assign_handle, on: :create

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :nickname, presence: true
  validates :gender, inclusion: { in: GENDERS }
  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :handle, presence: true, uniqueness: true, format: { with: HANDLE_FORMAT, message: "只能包含小寫英文、數字和底線，長度 3-30" }

  before_save { self.email = email.downcase }

  private

  def assign_handle
    return if handle.present?

    loop do
      candidate = "user#{SecureRandom.alphanumeric(6).downcase}"
      unless User.exists?(handle: candidate)
        self.handle = candidate
        break
      end
    end
  end
end
