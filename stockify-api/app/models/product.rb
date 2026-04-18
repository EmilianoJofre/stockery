class Product < ApplicationRecord
  belongs_to :company
  belongs_to :product_category, optional: true

  has_many :inventory_levels
  has_many :inventory_adjustments
  has_many :purchase_items
  has_many :sale_items

  before_validation :normalize_sku

  validates :name, :sku, :price, presence: true
  validates :sku, uniqueness: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :low_stock_threshold, numericality: { greater_than_or_equal_to: 0 }

  def inventory_total
    inventory_levels.sum(:quantity)
  end

  def inventory_for(store_id)
    inventory_levels.find_by(store_id: store_id)&.quantity.to_i
  end

  def low_stock?(store_id = nil)
    return false if low_stock_threshold.to_i.zero?

    return inventory_for(store_id) <= low_stock_threshold if store_id.present?

    inventory_levels.any? { |level| level.quantity <= low_stock_threshold }
  end

  private

  def normalize_sku
    self.sku = sku.to_s.strip.upcase
  end
end
