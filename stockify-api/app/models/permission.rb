class Permission < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :user_permissions, dependent: :destroy

  validates :key, :category, presence: true
  validates :key, uniqueness: true
  validates :key, format: { with: /\A[a-z_]+\.[a-z_]+\z/, message: "debe tener formato 'categoria.accion'" }
end
