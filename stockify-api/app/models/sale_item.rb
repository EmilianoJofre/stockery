class SaleItem < ApplicationRecord
  belongs_to :sale
  belongs_to :product

  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :snapshot_tax_exemption
  before_validation :calculate_subtotal

  # Las lineas de un documento emitido tampoco se pueden tocar: si se pudieran,
  # los montos del DTE cambiarian por debajo.
  before_save :guard_issued_document
  before_destroy :guard_issued_document

  private

  def guard_issued_document
    return unless sale&.issued?

    raise Sale::Immutable, "El documento #{sale.reference} ya fue emitido: no admite cambios en sus lineas"
  end

  # Se congela la condicion de exencion del producto al momento de la venta:
  # si el producto cambia despues, el documento ya emitido no debe alterarse.
  def snapshot_tax_exemption
    return if tax_exempt_changed?

    self.tax_exempt = product&.tax_exempt || false
  end

  def calculate_subtotal
    self.subtotal = quantity.to_i * unit_price.to_f
  end
end
