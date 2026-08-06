class InventoryMovement < ApplicationRecord
  # Ledger append-only del inventario: una fila por cada cambio de stock,
  # venga de una compra, una venta o un ajuste manual.
  REASONS = %w[purchase sale restock audit damage display expiry].freeze

  belongs_to :product
  belongs_to :store
  belongs_to :user
  belongs_to :inventory_lot, optional: true
  belongs_to :source, polymorphic: true, optional: true

  validates :quantity_change, numericality: { other_than: 0, only_integer: true }
  validates :reason, presence: true, inclusion: { in: REASONS }

  scope :inbound,  -> { where("quantity_change > 0") }
  scope :outbound, -> { where("quantity_change < 0") }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def inbound?
    quantity_change.positive?
  end

  # Valor economico del movimiento (positivo entra, negativo sale).
  def total_cost
    return nil if unit_cost.blank?

    unit_cost * quantity_change
  end
end
