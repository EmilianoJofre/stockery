class Purchase < ApplicationRecord
  belongs_to :supplier
  belongs_to :store
  belongs_to :user

  has_many :purchase_items, dependent: :destroy

  accepts_nested_attributes_for :purchase_items

  enum status: { draft: 0, received: 1 }

  validates :reference, presence: true, uniqueness: true
  validates :received_on, presence: true

  before_validation :assign_reference
  before_validation :calculate_total_amount

  def self.generate_reference
    "PO-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.alphanumeric(4).upcase}"
  end

  private

  def assign_reference
    self.reference = reference.presence || self.class.generate_reference
  end

  def calculate_total_amount
    self.total_amount = purchase_items.sum { |item| item.subtotal.presence || item.quantity.to_i * item.unit_cost.to_f }
  end
end
