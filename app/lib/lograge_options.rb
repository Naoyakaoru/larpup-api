# Lograge custom_options — single source of truth.
# Used in config/environments/production.rb and tested in spec/requests/logging_spec.rb.
#
# Standard lograge fields (method, path, status, duration, etc.) are output automatically.
# This module adds:
#   - request_id, ip           — always present
#   - user_id                  — when the controller set @current_user
#   - error                    — when the response is an error
#   - any log_context() fields — controller-specific debug data (sso_uid, conflict, etc.)
#
module LogrageOptions
  # Keys that lograge already outputs as top-level fields — don't duplicate them.
  STANDARD_KEYS = %i[
    method path format controller action status view db
    allocations duration location exception exception_object
    request_id remote_ip user_id error headers params
  ].to_set.freeze

  def self.custom_options
    lambda do |event|
      opts = {
        request_id: event.payload[:request_id],
        ip:         event.payload[:remote_ip],
      }
      opts[:user_id] = event.payload[:user_id] if event.payload[:user_id]
      opts[:error]   = event.payload[:error]   if event.payload[:error]

      # Forward any log_context() fields injected by controllers
      event.payload.each do |key, value|
        next if STANDARD_KEYS.include?(key.to_sym)
        next if value.nil?
        opts[key] = value
      end

      opts
    end
  end
end
