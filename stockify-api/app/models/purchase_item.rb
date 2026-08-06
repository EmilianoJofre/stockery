class PurchaseItem < ApplicationRecord
  belongs_to :purchase
  belongs_to :product

  has_many :inventory_lots

  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :unit_cost, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_subtotal

  private

  def calculate_subtotal
    self.subtotal = quantity.to_i * unit_cost.to_f
  end
end
