class InventoryManager
  class Error < StandardError; end

  def self.adjust!(product:, store:, user:, quantity_change:, reason:, note: nil)
    quantity_change = quantity_change.to_i
    raise Error, "Quantity change cannot be zero" if quantity_change.zero?

    inventory_level = InventoryLevel.lock.find_or_initialize_by(product: product, store: store)
    inventory_level.quantity = inventory_level.quantity.to_i + quantity_change

    raise Error, "Insufficient stock for #{product.name} in #{store.name}" if inventory_level.quantity.negative?

    inventory_level.save!

    InventoryAdjustment.create!(
      product: product,
      store: store,
      user: user,
      quantity_change: quantity_change,
      reason: reason,
      note: note
    )

    inventory_level
  end
end
