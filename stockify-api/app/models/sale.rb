class Sale < ApplicationRecord
  class Immutable < StandardError; end

  belongs_to :store
  belongs_to :user
  belongs_to :customer, optional: true
  belongs_to :caf_range, optional: true

  has_many :sale_items, dependent: :destroy

  accepts_nested_attributes_for :sale_items

  enum status: { pending: 0, completed: 1 }

  # Valores = codigos de tipo de documento del SII, para no mantener una tabla
  # de mapeo aparte.
  enum document_type: {
    factura:        33,
    factura_exenta: 34,
    boleta:         39,
    boleta_exenta:  41,
    nota_credito:   61
  }, _prefix: :document

  enum sii_status: {
    draft:    0,
    queued:   1,
    sent:     2,
    accepted: 3,
    rejected: 4
  }, _prefix: :sii

  validates :reference, presence: true, uniqueness: true
  validates :sold_on, presence: true
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0 }
  # Una factura identifica al receptor; una boleta no lo exige.
  validates :customer, presence: { message: "es obligatorio para una factura" },
                       if: -> { document_factura? || document_factura_exenta? }

  before_validation :assign_reference
  before_validation :calculate_amounts
  validate  :breakdown_must_balance
  before_update :guard_immutability

  def self.generate_reference
    "SO-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.alphanumeric(4).upcase}"
  end

  def issued?
    issued_at.present?
  end

  # Marca el documento como emitido y le asigna folio del CAF vigente.
  # Desde aca el documento queda inmutable: un DTE emitido no se edita, se
  # corrige con una nota de credito.
  def issue!
    raise Immutable, "El documento #{reference} ya fue emitido" if issued?

    self.class.transaction do
      folio, range = CafRange.assign_folio!(company: store.company, document_type: self.class.document_types[document_type])

      update_columns(
        folio: folio,
        caf_range_id: range.id,
        issued_at: Time.current,
        sii_status: self.class.sii_statuses[:queued],
        updated_at: Time.current
      )
    end

    self
  end

  private

  def assign_reference
    self.reference = reference.presence || self.class.generate_reference
  end

  # Los precios de venta son BRUTOS (IVA incluido), como el precio de gondola.
  # El neto se deriva del bruto y el IVA se obtiene por resta, de modo que
  # neto + IVA + exento == total siempre cuadre sin arrastre de redondeo.
  def calculate_amounts
    # Un documento emitido tiene montos congelados: recalcularlos podria alterar
    # un DTE ya emitido por diferencias de redondeo.
    return if issued?

    rate = tax_rate.presence || 0.19

    gross_taxable = 0
    gross_exempt  = 0

    sale_items.each do |item|
      amount = item.subtotal.presence || (item.quantity.to_i * item.unit_price.to_f)
      if item.tax_exempt
        gross_exempt += amount
      else
        gross_taxable += amount
      end
    end

    net = (gross_taxable / (1 + rate.to_f)).round
    self.net_amount    = net
    self.tax_amount    = gross_taxable - net
    self.exempt_amount = gross_exempt
    self.total_amount  = gross_taxable + gross_exempt
  end

  def breakdown_must_balance
    return if [net_amount, tax_amount, exempt_amount, total_amount].any?(&:blank?)

    sum = net_amount + tax_amount + exempt_amount
    return if (sum - total_amount).abs < 0.01

    errors.add(:total_amount, "no coincide con neto + IVA + exento (#{sum} vs #{total_amount})")
  end

  # Un documento emitido solo puede avanzar en su estado ante el SII.
  def guard_immutability
    return unless issued_at_was.present?

    mutable = %w[sii_status sii_track_id updated_at]
    blocked = changed - mutable
    return if blocked.empty?

    raise Immutable, "El documento #{reference} ya fue emitido y no admite cambios en: #{blocked.join(', ')}"
  end
end
