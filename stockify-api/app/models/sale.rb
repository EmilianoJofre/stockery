class Sale < ApplicationRecord
  belongs_to :store
  belongs_to :user

  has_many :sale_items, dependent: :destroy

  accepts_nested_attributes_for :sale_items

  enum status: { pending: 0, completed: 1 }

  validates :reference, presence: true, uniqueness: true
  validates :sold_on, presence: true

  before_validation :assign_reference
  before_validation :calculate_total_amount

  def self.generate_reference
    "SO-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.alphanumeric(4).upcase}"
  end

  private

  def assign_reference
    self.reference = reference.presence || self.class.generate_reference
  end

  def calculate_total_amount
    self.total_amount = sale_items.sum { |item| item.subtotal.presence || item.quantity.to_i * item.unit_price.to_f }
  end
end
