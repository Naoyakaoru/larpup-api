allowed_origins = if Rails.env.production?
  origins_env = ENV.fetch("ALLOWED_ORIGINS", "")
  origins_env.split(",").map(&:strip).reject(&:empty?)
else
  "*"
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins allowed_origins

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end
