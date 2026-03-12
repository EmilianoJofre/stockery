# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

allowed_origins = ENV.fetch(
  "FRONTEND_ORIGINS",
  "http://localhost:5173,http://127.0.0.1:5173,http://localhost:5174,http://127.0.0.1:5174,http://localhost:4173"
)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins.split(",").map(&:strip))

    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: true
  end
end
