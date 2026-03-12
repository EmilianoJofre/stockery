class JsonWebToken
  ALGORITHM = "HS256".freeze

  def self.encode(payload, expires_at: 24.hours.from_now)
    JWT.encode(payload.merge(exp: expires_at.to_i), secret_key, ALGORITHM)
  end

  def self.decode(token)
    return if token.blank?

    body = JWT.decode(token, secret_key, true, algorithm: ALGORITHM).first
    body.with_indifferent_access
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end

  def self.secret_key
    ENV.fetch("JWT_SECRET", Rails.application.secret_key_base)
  end
end
