module Auditable
  extend ActiveSupport::Concern

  included do
    class_attribute :audited_fields, default: nil

    has_many :audit_logs, as: :auditable, dependent: :destroy

    after_commit :log_created,   on: :create
    after_commit :log_updated,   on: :update
    after_commit :log_destroyed, on: :destroy
  end

  class_methods do
    def audit_fields(*fields)
      self.audited_fields = fields.map(&:to_s)
    end
  end

  private

  def log_created
    log_audit("created")
  end

  def log_updated
    relevant = previous_changes.except("updated_at", "created_at")
    relevant = relevant.slice(*self.class.audited_fields) if self.class.audited_fields
    return if relevant.empty?
    relevant = enrich_audit_changes(relevant) if respond_to?(:enrich_audit_changes, true)
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
