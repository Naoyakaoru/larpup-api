class User < ApplicationRecord
  has_secure_password validations: false

  # SSO users have no password; email/password users must set one on create
  validates :password, length: { minimum: 6 }, confirmation: true, if: -> { password.present? || (!persisted? && google_uid.blank? && line_uid.blank?) }

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [300, 300]
  end

  validate :avatar_content_type_and_size, if: -> { avatar.attached? && avatar.changed? }


  has_many :hosted_events, class_name: "Event", foreign_key: :host_id, dependent: :destroy
  has_many :event_members, dependent: :destroy
  has_many :joined_events, through: :event_members, source: :event
  has_many :owned_stores, class_name: "Store", foreign_key: :owner_id, dependent: :restrict_with_error

  GENDERS = %w[male female].freeze
  HANDLE_FORMAT = /\A[a-z0-9_]{3,30}\z/

  before_validation :assign_handle, on: :create

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :canonical_email, presence: true, uniqueness: { case_sensitive: false }
  validates :nickname, presence: true
  validates :gender, inclusion: { in: GENDERS }
  validates :handle, presence: true, uniqueness: true, format: { with: HANDLE_FORMAT, message: "只能包含小寫英文、數字和底線，長度 3-30" }

  before_validation :set_canonical_email
  before_save { self.email = email.downcase }

  def self.canonicalize_email(email_str)
    return nil if email_str.blank?

    email_str = email_str.downcase.strip
    parts = email_str.split('@')
    return email_str unless parts.length == 2

    local_part, domain = parts

    if domain == 'gmail.com' || domain == 'googlemail.com'
      local_part = local_part.split('+').first
      local_part = local_part.delete('.')
      "#{local_part}@gmail.com"
    else
      email_str
    end
  end

  private

  def set_canonical_email
    self.canonical_email = self.class.canonicalize_email(email)
  end

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

  def avatar_content_type_and_size
    unless avatar.content_type.in?(%w[image/jpeg image/png image/webp image/gif])
      errors.add(:avatar, "必須是圖片格式（JPG、PNG、WebP、GIF）")
    end
    if avatar.byte_size > 1.megabyte
      errors.add(:avatar, "不能超過 1MB")
    end
  end
end
