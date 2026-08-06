class InventoryLot < ApplicationRecord
  belongs_to :company
  belongs_to :product
  belongs_to :store
  belongs_to :purchase_item, optional: true

  has_many :inventory_movements, dependent: :nullify

  validates :received_on, presence: true
  validates :quantity_received, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :quantity_remaining, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :unit_cost, numericality: { greater_than_or_equal_to: 0 }
  validate :remaining_within_received

  # Todas las columnas van calificadas con el nombre de la tabla: estos scopes se
  # usan sobre queries que hacen join con `products`, y columnas como `id` serian
  # ambiguas sin el prefijo.
  scope :available, -> { where("inventory_lots.quantity_remaining > 0") }
  scope :perishable, -> { where.not(inventory_lots: { expiry_date: nil }) }

  # FEFO (First Expired, First Out): se despacha primero lo que vence antes.
  # Los lotes sin vencimiento van al final (NULLS LAST); entre iguales, el mas
  # antiguo primero, y el id desempata para que el orden sea determinista.
  scope :fefo, lambda {
    order(Arel.sql(
      "inventory_lots.expiry_date ASC NULLS LAST, " \
      "inventory_lots.received_on ASC, " \
      "inventory_lots.id ASC"
    ))
  }

  scope :expiring_on_or_before, ->(date) { perishable.where("inventory_lots.expiry_date <= ?", date) }
  scope :expired, ->(on = Date.current) { perishable.where("inventory_lots.expiry_date < ?", on) }

  def expired?(on = Date.current)
    expiry_date.present? && expiry_date < on
  end

  def days_to_expiry(from = Date.current)
    return nil if expiry_date.blank?

    (expiry_date - from).to_i
  end

  def quantity_consumed
    quantity_received - quantity_remaining
  end

  private

  def remaining_within_received
    return if quantity_remaining.blank? || quantity_received.blank?
    return if quantity_remaining <= quantity_received

    errors.add(:quantity_remaining, "no puede superar la cantidad recibida")
  end
end
