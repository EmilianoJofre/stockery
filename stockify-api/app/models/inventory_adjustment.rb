class InventoryAdjustment < ApplicationRecord
  belongs_to :product
  belongs_to :store
  belongs_to :user

  validates :quantity_change, numericality: { other_than: 0, only_integer: true }
  validates :reason, presence: true
end
