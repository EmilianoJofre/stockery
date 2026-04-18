require "csv"

module Products
  class Exporter
    HEADERS = %w[sku nombre categoría precio stock umbral activo].freeze

    def initialize(scope:)
      @scope = scope.includes(:product_category, inventory_levels: :store)
    end

    def to_csv
      CSV.generate(headers: true, encoding: "UTF-8") do |csv|
        csv << HEADERS
        @scope.each { |product| csv << row_for(product) }
      end
    end

    private

    def row_for(product)
      [
        product.sku,
        product.name,
        product.product_category&.name,
        product.price,
        product.inventory_levels.sum(&:quantity),
        product.low_stock_threshold,
        product.active ? "sí" : "no"
      ]
    end
  end
end
