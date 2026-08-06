class AddLotFieldsToPurchaseItems < ActiveRecord::Migration[7.1]
  # La recepcion de una compra es el momento en que se conoce el lote y su
  # vencimiento, asi que la linea de compra es donde se capturan.
  def change
    add_column :purchase_items, :lot_code, :string
    add_column :purchase_items, :expiry_date, :date
  end
end
