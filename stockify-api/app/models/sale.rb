class Sale < ApplicationRecord
  class Immutable < StandardError; end

  # CodRef del SII para el bloque Referencia de una nota de credito.
  REFERENCE_CODES = { annul: 1, fix_text: 2, fix_amounts: 3 }.freeze

  belongs_to :store
  belongs_to :user
  belongs_to :customer, optional: true
  belongs_to :caf_range, optional: true
  belongs_to :references_sale, class_name: "Sale", optional: true

  has_many :credit_notes, class_name: "Sale", foreign_key: :references_sale_id, dependent: :nullify
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
  # El SII no acepta una nota de credito que no diga que documento corrige.
  validates :references_sale, presence: { message: "es obligatorio en una nota de credito" },
                              if: -> { document_nota_credito? }
  validates :reference_code, inclusion: { in: REFERENCE_CODES.values },
                             if: -> { document_nota_credito? }

  # Documentos que suman ingresos: las notas de credito restan, no suman.
  scope :revenue_documents, -> { where.not(document_type: document_types[:nota_credito]) }
  scope :credit_note_documents, -> { where(document_type: document_types[:nota_credito]) }
  scope :not_annulled, -> { where(annulled_at: nil) }

  # Ingreso neto de un periodo.
  #
  # Se restan solo las notas de credito que NO anulan: las anulaciones ya se
  # descuentan al excluir el documento anulado, y restarlas ademas contaria el
  # mismo monto dos veces.
  def self.net_revenue(scope)
    gross = scope.completed.revenue_documents.not_annulled.sum(:total_amount)
    credited = scope.completed.credit_note_documents
      .where.not(reference_code: REFERENCE_CODES[:annul])
      .sum(:total_amount)

    (gross - credited).to_f.round(2)
  end

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

  def annulled?
    annulled_at.present?
  end

  def credit_note?
    document_nota_credito?
  end

  # Cuanto queda por acreditar del documento: impide emitir notas de credito
  # por mas de lo que se vendio.
  def credited_amount
    credit_notes.sum(:total_amount)
  end

  def creditable_amount
    total_amount - credited_amount
  end

  # Emite el documento: reserva folio, lo congela y lo deja en cola para el
  # SII. Desde aca es inmutable: un DTE emitido no se edita, se corrige con
  # una nota de credito.
  #
  # La logica vive en Dte::Emitter porque depende de la configuracion de la
  # empresa (quien asigna el folio, que proveedor transmite).
  def issue!
    Dte::Emitter.new(self).issue!
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
