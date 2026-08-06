# Claves de Active Record Encryption (usadas por DteSetting#api_key).
#
# Se derivan de secret_key_base en vez de exigir tres secretos nuevos: asi el
# deploy existente sigue funcionando sin tocar .env.production, y la seguridad
# queda anclada al mismo secreto que ya protege la aplicacion.
#
# Para rotar las llaves sin rotar secret_key_base, define las tres variables
# de entorno; tienen precedencia.
Rails.application.config.to_prepare do
  generator = ActiveSupport::KeyGenerator.new(
    Rails.application.secret_key_base,
    hash_digest_class: OpenSSL::Digest::SHA256
  )

  ActiveRecord::Encryption.config.primary_key =
    ENV["AR_ENCRYPTION_PRIMARY_KEY"].presence ||
    generator.generate_key("stockery/ar-encryption/primary", 32)

  ActiveRecord::Encryption.config.deterministic_key =
    ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"].presence ||
    generator.generate_key("stockery/ar-encryption/deterministic", 32)

  ActiveRecord::Encryption.config.key_derivation_salt =
    ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"].presence ||
    generator.generate_key("stockery/ar-encryption/salt", 32)
end
