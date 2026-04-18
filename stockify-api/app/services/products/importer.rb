require "bigdecimal"

module Products
  class Importer
    TEMPLATE_HEADERS = %w[
      sku
      name
      description
      price
      low_stock_threshold
      category
      active
    ].freeze
    REQUIRED_HEADERS = %w[sku name price].freeze
    DEFAULT_LOW_STOCK_THRESHOLD = 10

    def initialize(company:, file:)
      @company = company
      @file = file
      @created_count = 0
      @updated_count = 0
      @errors = []
      @processed_rows = 0
    end

    def call
      parsed_file = ImportFileParser.new(file: file).call
      validate_headers!(parsed_file.headers)

      parsed_file.rows.each do |row|
        import_row(row)
      end

      raise ImportError, "El archivo no contiene filas con datos para importar." if processed_rows.zero? && errors.empty?

      {
        status: import_status,
        message: import_message,
        summary: {
          total_rows: total_rows,
          processed_rows: total_rows,
          successful_rows: created_count + updated_count,
          created: created_count,
          updated: updated_count,
          errors: errors.count
        },
        errors: errors
      }
    end

    private

    attr_reader :company, :file, :created_count, :updated_count, :errors, :processed_rows

    def import_row(row)
      attributes = row[:data]
      return if blank_row?(attributes)

      @processed_rows += 1

      ActiveRecord::Base.transaction(requires_new: true) do
        product = find_product(attributes.fetch("sku", ""))
        created = product.new_record?

        product.assign_attributes(
          name: attributes["name"].to_s.strip,
          description: parse_description(attributes["description"], product),
          price: parse_price!(attributes["price"]),
          low_stock_threshold: parse_threshold(attributes["low_stock_threshold"], product),
          active: parse_active(attributes["active"], product),
          product_category: resolve_category(attributes["category"], product)
        )

        product.save!
        ensure_inventory_rows(product) if created

        created ? @created_count += 1 : @updated_count += 1
      end
    rescue Products::ImportError, ActiveRecord::RecordInvalid => e
      errors << {
        row: row[:row_number],
        sku: attributes["sku"].presence,
        message: human_error_message(e)
      }
    end

    def find_product(sku_value)
      sku = sku_value.to_s.strip.upcase
      raise ImportError, "El SKU es obligatorio." if sku.blank?

      product = company.products.find_by(sku: sku)
      return product if product.present?

      if Product.where.not(company_id: company.id).exists?(sku: sku)
        raise ImportError, "El SKU #{sku} ya existe en otra compañía y no puede reutilizarse."
      end

      company.products.build(sku: sku)
    end

    def resolve_category(value, product)
      normalized = normalize_lookup(value)
      return product.product_category if normalized.blank? && product.persisted?
      return nil if normalized.blank?

      category = category_index[normalized]
      return category if category.present?

      raise ImportError, "La categoría \"#{value}\" no existe en esta compañía."
    end

    def parse_price!(value)
      normalized = normalize_decimal(value)
      raise ImportError, "El precio es obligatorio." if normalized.blank?

      BigDecimal(normalized)
    rescue ArgumentError
      raise ImportError, "El precio \"#{value}\" no es válido."
    end

    def parse_threshold(value, product)
      return product.low_stock_threshold if value.blank? && product.persisted?
      return DEFAULT_LOW_STOCK_THRESHOLD if value.blank?

      Integer(value.to_s.strip)
    rescue ArgumentError
      raise ImportError, "El umbral de stock bajo \"#{value}\" no es válido."
    end

    def parse_active(value, product)
      return product.active if value.blank? && product.persisted?
      return true if value.blank?

      case normalize_lookup(value)
      when "true", "1", "si", "yes", "activo"
        true
      when "false", "0", "no", "inactivo"
        false
      else
        raise ImportError, "El valor de activo \"#{value}\" no es válido. Usa true/false."
      end
    end

    def parse_description(value, product)
      return product.description if value.blank? && product.persisted?

      value.presence
    end

    def ensure_inventory_rows(product)
      company.stores.find_each do |store|
        InventoryLevel.find_or_create_by!(product: product, store: store) do |level|
          level.quantity = 0
        end
      end
    end

    def validate_headers!(headers)
      missing_headers = REQUIRED_HEADERS - headers.compact
      return if missing_headers.empty?

      raise ImportError, "Faltan columnas obligatorias: #{missing_headers.join(', ')}."
    end

    def blank_row?(attributes)
      attributes.values.all?(&:blank?)
    end

    def human_error_message(error)
      return error.record.errors.full_messages.to_sentence if error.is_a?(ActiveRecord::RecordInvalid)

      error.message
    end

    def import_status
      return "success" if errors.empty?
      return "failed" if created_count.zero? && updated_count.zero?

      "partial_success"
    end

    def import_message
      case import_status
      when "success"
        "Importación completada correctamente."
      when "partial_success"
        "Importación completada con observaciones."
      else
        "No se pudo importar ninguna fila."
      end
    end

    def total_rows
      created_count + updated_count + errors.count
    end

    def category_index
      @category_index ||= company.product_categories.each_with_object({}) do |category, index|
        index[normalize_lookup(category.name)] = category
        index[normalize_lookup(category.slug)] = category
      end
    end

    def normalize_lookup(value)
      I18n.transliterate(value.to_s)
        .strip
        .downcase
        .gsub(/\s+/, " ")
    end

    def normalize_decimal(value)
      raw = value.to_s.strip.gsub(/[^\d,.\-]/, "")
      return raw if raw.blank?

      if raw.include?(",") && raw.include?(".")
        raw.rindex(",") > raw.rindex(".") ? raw.delete(".").tr(",", ".") : raw.delete(",")
      elsif raw.include?(",")
        raw.tr(",", ".")
      else
        raw
      end
    end
  end
end
