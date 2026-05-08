class AddressSerializer
  def initialize(address, include_audit_logs: false)
    @address = address
    @include_audit_logs = include_audit_logs
  end

  def as_json(*)
    data = {
      id: @address.id,
      name: @address.name,
      address: @address.address,
      map_url: @address.map_url,
      region: @address.region,
      deleted_at: @address.deleted_at
    }
    if @include_audit_logs
      data[:audit_logs] = @address.audit_logs.order(created_at: :desc).limit(50).map do |log|
        {
          id: log.id,
          action: log.action,
          user_id: log.user_id,
          metadata: log.metadata,
          created_at: log.created_at
        }
      end
    end
    data
  end
end
