class ApplicationController < ActionController::API
  include ActionController::Cookies

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
  rescue_from InventoryManager::Error, with: :render_domain_error

  private

  attr_reader :current_user

  def authenticate_user!
    payload = JsonWebToken.decode(auth_token)
    @current_user = User.find_by(id: payload[:user_id]) if payload.present?
    return if @current_user.present?

    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def authorize_roles!(*roles)
    return if current_user.present? && roles.map(&:to_s).include?(current_user.role)

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def issue_auth_cookie(user)
    token = JsonWebToken.encode(user_id: user.id, role: user.role)

    cookies.signed[:stockify_token] = {
      value: token,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?,
      expires: 24.hours.from_now
    }
  end

  def clear_auth_cookie
    cookies.delete(:stockify_token)
  end

  def capabilities_for(user)
    {
      can_manage_products: user.admin? || user.manager?,
      can_manage_inventory: user.admin? || user.manager?,
      can_manage_purchases: user.admin? || user.manager?,
      can_manage_sales: true,
      can_view_reports: user.admin? || user.manager?
    }
  end

  def serialize_user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      last_login_at: user.last_login_at,
      capabilities: capabilities_for(user)
    }
  end

  def serialize_store(store)
    {
      id: store.id,
      name: store.name,
      code: store.code,
      address: store.address,
      active: store.active
    }
  end

  def serialize_supplier(supplier)
    {
      id: supplier.id,
      name: supplier.name,
      contact_name: supplier.contact_name,
      email: supplier.email,
      phone: supplier.phone,
      notes: supplier.notes,
      active: supplier.active
    }
  end

  def serialize_product(product)
    {
      id: product.id,
      name: product.name,
      sku: product.sku,
      description: product.description,
      price: product.price.to_f.round(2),
      low_stock_threshold: product.low_stock_threshold,
      active: product.active,
      inventory_total: product.inventory_total,
      low_stock: product.low_stock?,
      store_quantities: product.inventory_levels.map do |level|
        {
          store_id: level.store_id,
          store_name: level.store.name,
          quantity: level.quantity,
          low_stock: level.low_stock?
        }
      end
    }
  end

  def serialize_inventory_level(level)
    {
      id: level.id,
      product_id: level.product_id,
      product_name: level.product.name,
      sku: level.product.sku,
      store_id: level.store_id,
      store_name: level.store.name,
      quantity: level.quantity,
      threshold: level.product.low_stock_threshold,
      low_stock: level.low_stock?,
      updated_at: level.updated_at
    }
  end

  def serialize_adjustment(adjustment)
    {
      id: adjustment.id,
      product_name: adjustment.product.name,
      sku: adjustment.product.sku,
      store_name: adjustment.store.name,
      actor_name: adjustment.user.name,
      quantity_change: adjustment.quantity_change,
      reason: adjustment.reason,
      note: adjustment.note,
      created_at: adjustment.created_at
    }
  end

  def serialize_purchase(purchase)
    {
      id: purchase.id,
      reference: purchase.reference,
      status: purchase.status,
      received_on: purchase.received_on,
      total_amount: purchase.total_amount.to_f.round(2),
      notes: purchase.notes,
      supplier: serialize_supplier(purchase.supplier),
      store: serialize_store(purchase.store),
      user: serialize_user(purchase.user),
      items: purchase.purchase_items.map do |item|
        {
          id: item.id,
          product_id: item.product_id,
          product_name: item.product.name,
          sku: item.product.sku,
          quantity: item.quantity,
          unit_cost: item.unit_cost.to_f.round(2),
          subtotal: item.subtotal.to_f.round(2)
        }
      end
    }
  end

  def serialize_sale(sale)
    {
      id: sale.id,
      reference: sale.reference,
      status: sale.status,
      sold_on: sale.sold_on,
      customer_name: sale.customer_name,
      total_amount: sale.total_amount.to_f.round(2),
      notes: sale.notes,
      store: serialize_store(sale.store),
      user: serialize_user(sale.user),
      items: sale.sale_items.map do |item|
        {
          id: item.id,
          product_id: item.product_id,
          product_name: item.product.name,
          sku: item.product.sku,
          quantity: item.quantity,
          unit_price: item.unit_price.to_f.round(2),
          subtotal: item.subtotal.to_f.round(2)
        }
      end
    }
  end

  def auth_token
    cookies.signed[:stockify_token].presence || bearer_token
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    return if header.blank?

    header.split.last
  end

  def render_not_found(error)
    render json: { error: error.message }, status: :not_found
  end

  def render_unprocessable_entity(error)
    render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def render_parameter_missing(error)
    render json: { error: error.message }, status: :bad_request
  end

  def render_domain_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end
