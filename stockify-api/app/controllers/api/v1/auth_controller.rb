module Api
  module V1
    class AuthController < ApplicationController
      DEMO_EMAILS = {
        "owner"   => "owner@demo.stockery.app",
        "admin"   => "admin@demo.stockery.app",
        "manager" => "manager@demo.stockery.app",
        "clerk"   => "clerk@demo.stockery.app"
      }.freeze

      before_action :authenticate_user!, only: [:me, :logout]

      def login
        user = User.find_by(email: params[:email].to_s.downcase)

        if user&.authenticate(params[:password].to_s)
          user.update!(last_login_at: Time.current)
          issue_auth_cookie(user)
          render json: { user: serialize_user(user) }
        else
          render json: { error: "Correo o contrasena invalidos" }, status: :unauthorized
        end
      end

      def demo_login
        role = params[:role].to_s
        user = User.find_by(email: DEMO_EMAILS[role])

        return render json: { error: "Cuenta demo no encontrada" }, status: :not_found unless user

        user.update!(last_login_at: Time.current)
        issue_auth_cookie(user)
        render json: { user: serialize_user(user) }
      end

      def me
        render json: { user: serialize_user(current_user) }
      end

      def logout
        clear_auth_cookie
        head :no_content
      end
    end
  end
end
