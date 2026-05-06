module JwtAuthenticatable
  SECRET = ENV.fetch("SECRET_KEY_BASE")

  def self.encode(payload)
    JWT.encode(payload.merge(exp: 30.days.from_now.to_i), SECRET, "HS256")
  end

  def self.decode(token)
    JWT.decode(token, SECRET, true, algorithm: "HS256").first
  rescue JWT::DecodeError
    nil
  end
end
