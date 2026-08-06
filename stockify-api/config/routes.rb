Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      post "auth/demo_login", to: "auth#demo_login"
      get  "auth/me", to: "auth#me"
      delete "auth/logout", to: "auth#logout"

      get "dashboard", to: "dashboard#show"
      resources :stores, only: [:index]
      resources :products do
        collection do
          get :export
          get :import_template
          post :import
        end
      end
      resources :product_categories, only: [:index, :create, :update]
      resources :suppliers
      resources :purchases, only: [:index, :show, :create]
      resources :sales, only: [:index, :show, :create] do
        member do
          post :issue
        end
      end
      resources :customers, only: [:index, :show, :create, :update]

      resources :users, only: [:index, :show, :create, :update, :destroy] do
        member do
          patch :update_permissions
        end
      end

      # Configuracion de facturacion electronica (DTE) y folios CAF.
      get   "billing/settings",       to: "billing#show"
      put   "billing/settings",       to: "billing#update"
      post  "billing/caf_ranges",     to: "billing#create_caf_range"
      patch "billing/caf_ranges/:id", to: "billing#update_caf_range"

      get  "catalog/permissions", to: "catalog#permissions"
      get  "catalog/roles",       to: "catalog#roles"

      get  "inventory",              to: "inventory#index"
      get  "inventory/adjustments",  to: "inventory#adjustments"
      get  "inventory/lots",         to: "inventory#lots"
      post "inventory/adjust",       to: "inventory#adjust"

      get "reports/stock_levels(.:format)",         to: "reports#stock_levels"
      get "reports/top_selling_products(.:format)", to: "reports#top_selling_products"
      get "reports/low_stock(.:format)",            to: "reports#low_stock"
    end
  end
end
