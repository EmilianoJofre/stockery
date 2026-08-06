class ApplicationController < ActionController::API
  include ActionController::Cookies

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
  rescue_from InventoryManager::Error, with: :render_domain_error
  # Errores de dominio tributario: intentar editar un DTE emitido o quedarse sin
  # folios son condiciones esperables, no fallas del servidor.
  rescue_from Sale::Immutable, with: :render_domain_error
  rescue_from CafRange::Exhausted, with: :render_domain_error
  rescue_from Dte::TransmissionError, with: :render_domain_error

  private

  attr_reader :current_user

  def authenticate_user!
    payload = JsonWebToken.decode(auth_token)
    @current_user = User.includes(:company, :extra_permissions).find_by(id: payload[:user_id]) if payload.present?
    return if @current_user.present? && @current_user.active?

    render json: { error: "No autorizado" }, status: :unauthorized
  end

  def current_company
    current_user&.company
  end

  def authorize!(permission_key)
    return if current_user&.can?(permission_key)

    render json: { error: "Acceso denegado" }, status: :forbidden
  end

  # Kept for backward-compat in auth_controller demo_login flow — prefer authorize!
  def authorize_roles!(*roles)
    return if current_user.present? && roles.map(&:to_s).include?(current_user.role)

    render json: { error: "Acceso denegado" }, status: :forbidden
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

  def serialize_user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      active: user.active,
      last_login_at: user.last_login_at,
      company: { id: user.company_id, name: user.company.name },
      permissions: user.effective_permission_keys
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

  def serialize_product_category(category)
    {
      id: category.id,
      name: category.name,
      slug: category.slug,
      icon: category.icon,
      active: category.active
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
      # Necesario en el frontend para calcular el desglose neto/IVA/exento en vivo.
      tax_exempt: product.tax_exempt,
      product_category_id: product.product_category_id,
      product_category: product.product_category ? serialize_product_category(product.product_category) : nil,
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

  # Serializa un InventoryMovement. Conserva las claves previas para no romper
  # el frontend, y agrega la trazabilidad del lote de origen.
  def serialize_adjustment(movement)
    {
      id: movement.id,
      product_name: movement.product.name,
      sku: movement.product.sku,
      store_name: movement.store.name,
      actor_name: movement.user.name,
      quantity_change: movement.quantity_change,
      reason: movement.reason,
      note: movement.note,
      lot_code: movement.inventory_lot&.lot_code,
      expiry_date: movement.inventory_lot&.expiry_date,
      created_at: movement.created_at
    }
  end

  def serialize_inventory_lot(lot)
    {
      id: lot.id,
      product_id: lot.product_id,
      product_name: lot.product.name,
      sku: lot.product.sku,
      store_id: lot.store_id,
      store_name: lot.store.name,
      lot_code: lot.lot_code,
      expiry_date: lot.expiry_date,
      days_to_expiry: lot.days_to_expiry,
      expired: lot.expired?,
      received_on: lot.received_on,
      unit_cost: lot.unit_cost.to_f.round(2),
      quantity_received: lot.quantity_received,
      quantity_remaining: lot.quantity_remaining
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
      # ─── Documento tributario ───
      document_type: sale.document_type,
      document_code: Sale.document_types[sale.document_type],
      folio: sale.folio,
      issued: sale.issued?,
      issued_at: sale.issued_at,
      sii_status: sale.sii_status,
      net_amount: sale.net_amount.to_f.round(2),
      tax_amount: sale.tax_amount.to_f.round(2),
      exempt_amount: sale.exempt_amount.to_f.round(2),
      tax_rate: sale.tax_rate.to_f,
      customer: sale.customer && serialize_customer(sale.customer),
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
          subtotal: item.subtotal.to_f.round(2),
          tax_exempt: item.tax_exempt
        }
      end
    }
  end

  def serialize_customer(customer)
    {
      id: customer.id,
      rut: customer.rut,
      formatted_rut: customer.formatted_rut,
      name: customer.name,
      giro: customer.giro,
      email: customer.email,
      phone: customer.phone,
      address: customer.address,
      active: customer.active
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
