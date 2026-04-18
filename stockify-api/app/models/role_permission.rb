class RolePermission < ApplicationRecord
  belongs_to :permission

  VALID_ROLES = %w[owner admin manager clerk].freeze

  validates :role, presence: true, inclusion: { in: VALID_ROLES }
  validates :permission_id, uniqueness: { scope: :role }
end
