class User < ApplicationRecord
  has_secure_password

  belongs_to :company
  has_many :inventory_movements
  has_many :purchases
  has_many :sales
  has_many :user_permissions, dependent: :destroy
  has_many :extra_permissions, through: :user_permissions, source: :permission

  enum role: { admin: 0, manager: 1, clerk: 2, owner: 3 }

  scope :active, -> { where(active: true) }

  before_validation :normalize_email

  validates :name, :email, :role, :company_id, presence: true
  validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def can?(permission_key)
    effective_permission_keys.include?(permission_key.to_s)
  end

  def effective_permission_keys
    role_keys = RolePermission.joins(:permission)
      .where(role: role)
      .pluck("permissions.key")
    user_keys = extra_permissions.pluck(:key)
    (role_keys + user_keys).uniq
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
