module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_logs, as: :auditable, dependent: :destroy

    after_commit :log_created,  on: :create
    after_commit :log_updated,  on: :update
    after_commit :log_destroyed, on: :destroy
  end

  private

  def log_created
    log_audit("created")
  end

  def log_updated
    relevant = previous_changes.except("updated_at", "created_at")
    return if relevant.empty?
    log_audit("updated", changes: relevant)
  end

  def log_destroyed
    log_audit("deleted")
  end

  def log_audit(action, metadata = {})
    return unless Current.user
    AuditLog.create!(auditable: self, user: Current.user, action: action, metadata: metadata)
  end
end
