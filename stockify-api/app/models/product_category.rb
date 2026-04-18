class ProductCategory < ApplicationRecord
  belongs_to :company
  has_many :products, dependent: :nullify

  before_validation :normalize_slug

  validates :name, presence: true
  validates :name, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :slug, presence: true
  validates :slug, uniqueness: { scope: :company_id }

  scope :active, -> { where(active: true) }

  private

  def normalize_slug
    self.slug = name.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "") if slug.blank?
  end
end
