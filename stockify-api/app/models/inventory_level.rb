class InventoryLevel < ApplicationRecord
  belongs_to :product
  belongs_to :store

  validates :quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :product_id, uniqueness: { scope: :store_id }

  def low_stock?
    product.low_stock?(store_id)
  end
end
