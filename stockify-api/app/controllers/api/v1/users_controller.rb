module Api
  module V1
    class UsersController < BaseController
      before_action :set_user, only: [:show, :update, :destroy, :update_permissions]

      before_action only: [:index, :show]             do authorize!("users.view")   end
      before_action only: [:create]                   do authorize!("users.create") end
      before_action only: [:update, :update_permissions] do authorize!("users.edit") end
      before_action only: [:destroy]                  do authorize!("users.delete") end

      def index
        users = current_company.users
          .includes(:extra_permissions, :user_permissions)
          .order(:name)
        render json: { users: users.map { |u| serialize_user_detail(u) } }
      end

      def show
        render json: { user: serialize_user_detail(@user) }
      end

      def create
        user = current_company.users.build(user_create_params)
        user.save!
        render json: { user: serialize_user_detail(user) }, status: :created
      end

      def update
        check_self_demotion
        return if performed?

        @user.update!(user_update_params)
        render json: { user: serialize_user_detail(@user.reload) }
      end

      def destroy
        check_last_owner
        return if performed?

        @user.update!(active: false)
        head :no_content
      end

      def update_permissions
        permission_ids = Array(params[:permission_ids]).map(&:to_i)
        permissions = Permission.where(id: permission_ids)

        @user.user_permissions.delete_all
        permissions.each { |p| @user.user_permissions.create!(permission: p) }

        render json: { user: serialize_user_detail(@user.reload) }
      end

      private

      def set_user
        @user = current_company.users.find(params[:id])
      end

      def user_create_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
      end

      def user_update_params
        allowed = [:name, :email, :role, :active]
        allowed += [:password, :password_confirmation] if params.dig(:user, :password).present?
        params.require(:user).permit(allowed)
      end

      def check_self_demotion
        return unless @user.id == current_user.id
        return unless params.dig(:user, :role).present?

        new_role_value = User.roles[params[:user][:role].to_s]
        current_role_value = User.roles[current_user.role]
        return unless new_role_value && new_role_value < current_role_value

        render json: { error: "No puedes degradar tu propio rol" }, status: :unprocessable_entity
      end

      def check_last_owner
        return unless @user.owner?
        return unless current_company.users.active.where(role: :owner).count <= 1

        render json: { error: "No se puede desactivar al ultimo owner de la compania" }, status: :unprocessable_entity
      end

      def serialize_user_detail(user)
        base = serialize_user(user)
        base.merge(
          extra_permission_ids: user.user_permissions.map(&:permission_id),
          role_permissions: RolePermission.joins(:permission)
            .where(role: user.role)
            .pluck("permissions.key")
        )
      end
    end
  end
end
