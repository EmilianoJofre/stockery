class CafRange < ApplicationRecord
  class Exhausted < StandardError; end

  belongs_to :company
  has_many :sales, dependent: :nullify

  validates :document_type, :range_start, :range_end, :next_folio, presence: true
  validates :range_start, numericality: { greater_than: 0, only_integer: true }
  validate  :range_bounds

  scope :active, -> { where(active: true) }
  scope :for_document, ->(code) { where(document_type: code) }

  def exhausted?
    next_folio > range_end
  end

  def expired?(on = Date.current)
    expires_on.present? && expires_on < on
  end

  def available_folios
    return 0 if exhausted?

    range_end - next_folio + 1
  end

  # Entrega el siguiente folio y avanza el rango de forma atomica.
  #
  # El SELECT ... FOR UPDATE es lo que impide que dos ventas simultaneas reciban
  # el mismo folio: un folio duplicado es un documento tributario invalido.
  def self.assign_folio!(company:, document_type:)
    transaction do
      range = active
        .for_document(document_type)
        .where("next_folio <= range_end")
        .where("expires_on IS NULL OR expires_on >= ?", Date.current)
        .where(company: company)
        .order(:range_start)
        .lock
        .first

      unless range
        raise Exhausted, "No hay folios disponibles para el tipo de documento #{document_type}. " \
                         "Solicita un nuevo CAF al SII."
      end

      folio = range.next_folio
      range.update!(next_folio: folio + 1)

      [folio, range]
    end
  end

  private

  def range_bounds
    return if range_start.blank? || range_end.blank?

    errors.add(:range_end, "debe ser mayor o igual que el folio inicial") if range_end < range_start
  end
end
