module Api
  module V1
    class CatalogController < BaseController
      before_action do
        authorize!("users.view")
      end

      def permissions
        perms = Permission.order(:category, :key).group_by(&:category)
        render json: {
          permissions: perms.transform_values do |list|
            list.map { |p| { id: p.id, key: p.key, description: p.description, category: p.category } }
          end
        }
      end

      def roles
        role_map = RolePermission.joins(:permission)
          .group_by(&:role)
          .transform_values { |rps| rps.map { |rp| rp.permission.key } }

        roles = RolePermission::VALID_ROLES.map do |role|
          { key: role, permissions: role_map[role] || [] }
        end

        render json: { roles: roles }
      end
    end
  end
end
