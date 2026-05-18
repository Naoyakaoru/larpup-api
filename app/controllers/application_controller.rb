class ApplicationController < ActionController::API
  before_action :authenticate!

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  def authenticate!
    token = request.headers["Authorization"]&.split(" ")&.last
    payload = JwtAuthenticatable.decode(token)
    @current_user = User.find_by(id: payload&.dig("user_id"))
    Current.user = @current_user
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def current_user
    @current_user
  end

  def not_found
    render json: { error: "Not found" }, status: :not_found
  end

  def require_admin!
    render json: { error: "Forbidden" }, status: :forbidden unless current_user&.is_admin?
  end

  # Lograge hook: inject extra fields into each request log line
  def append_info_to_payload(payload)
    super
    payload[:user_id]   = @current_user&.id
    payload[:remote_ip] = request.remote_ip
    # Merge any controller-specific debug context (set via log_context)
    payload.merge!(request.env.fetch("app.log_context", {}))
  end

  # Call this from any controller action to attach extra fields to the log line.
  #
  # Examples:
  #   log_context(line_uid: uid, email: email)
  #   log_context(conflict: "email_taken", canonical_email: canonical)
  #
  def log_context(hash)
    request.env["app.log_context"] ||= {}
    request.env["app.log_context"].merge!(hash)
  end
end
