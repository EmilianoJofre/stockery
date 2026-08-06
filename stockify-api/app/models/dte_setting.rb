class DteSetting < ApplicationRecord
  PROVIDERS = %w[simulated openfactura].freeze
  ENVIRONMENTS = %w[sandbox production].freeze
  FOLIO_STRATEGIES = %w[own_caf provider].freeze

  belongs_to :company

  # La credencial del proveedor nunca queda en claro en la base.
  encrypts :api_key_ciphertext

  validates :provider, inclusion: { in: PROVIDERS }
  validates :environment, inclusion: { in: ENVIRONMENTS }
  validates :folio_strategy, inclusion: { in: FOLIO_STRATEGIES }
  validate :api_key_required_for_remote_providers

  def api_key
    api_key_ciphertext
  end

  def api_key=(value)
    self.api_key_ciphertext = value
  end

  def simulated?
    provider == "simulated"
  end

  def provider_assigns_folio?
    folio_strategy == "provider"
  end

  def to_provider
    Dte::Providers.build(self)
  end

  private

  def api_key_required_for_remote_providers
    return if simulated?
    return if api_key_ciphertext.present?

    errors.add(:api_key, "es obligatoria para el proveedor #{provider}")
  end
end
