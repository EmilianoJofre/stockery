class Store < ApplicationRecord
  belongs_to :company

  has_many :inventory_levels
  has_many :inventory_adjustments
  has_many :purchases
  has_many :sales

  scope :active, -> { where(active: true) }

  before_validation :normalize_code

  validates :name, :code, presence: true
  validates :code, uniqueness: true

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end
end
