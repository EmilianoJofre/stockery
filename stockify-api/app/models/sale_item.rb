class SaleItem < ApplicationRecord
  belongs_to :sale
  belongs_to :product

  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_subtotal

  private

  def calculate_subtotal
    self.subtotal = quantity.to_i * unit_price.to_f
  end
end
