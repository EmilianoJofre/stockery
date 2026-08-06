class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :stores, dependent: :destroy
  has_many :suppliers, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :product_categories, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :caf_ranges, dependent: :destroy
  has_one  :dte_setting, dependent: :destroy
  has_many :inventory_lots, dependent: :destroy

  def default_store
    stores.active.order(:created_at).first
  end

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  before_validation :normalize_slug

  private

  def normalize_slug
    self.slug = slug.to_s.strip.downcase.gsub(/[^a-z0-9\-]/, "-")
  end
end
