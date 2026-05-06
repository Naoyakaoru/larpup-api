module AuthHelpers
  def auth_header(user)
    token = JwtAuthenticatable.encode(user_id: user.id)
    { "Authorization" => "Bearer #{token}" }
  end
end
