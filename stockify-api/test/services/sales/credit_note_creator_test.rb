require "test_helper"

module Sales
  class CreditNoteCreatorTest < ActiveSupport::TestCase
    setup do
      scenario = full_scenario
      @company = scenario[:company]
      @store   = scenario[:store]
      @user    = scenario[:user]
      @product = create_product(@company)
      stock!(product: @product, store: @store, user: @user, quantity: 50)
    end

    def level
      InventoryLevel.find_by(product: @product, store: @store).quantity
    end

    test "una devolucion total anula el documento y restituye el stock" do
      sale = create_sale(company: @company, user: @user, product: @product,
                         quantity: 8, unit_price: 1_190, issue: true)
      assert_equal 42, level

      note = CreditNoteCreator.new(sale: sale, user: @user, params: { reason: "Arrepentimiento" }).call

      assert_equal "nota_credito", note.document_type
      assert_equal Sale::REFERENCE_CODES[:annul], note.reference_code
      assert_equal sale.id, note.references_sale_id
      assert note.folio.present?, "la nota de credito debe llevar su propio folio"
      assert sale.reload.annulled?
      assert_equal 50, level
    end

    test "una devolucion parcial no anula el documento" do
      sale = create_sale(company: @company, user: @user, product: @product,
                         quantity: 10, unit_price: 1_000, issue: true)

      note = CreditNoteCreator.new(sale: sale, user: @user, params: {
        items: [{ product_id: @product.id, quantity: 4 }]
      }).call

      assert_equal Sale::REFERENCE_CODES[:fix_amounts], note.reference_code
      assert_not sale.reload.annulled?
      assert_equal 44, level
      assert_equal 4_000, note.total_amount.to_i
    end

    test "varias devoluciones parciales terminan anulando el documento" do
      sale = create_sale(company: @company, user: @user, product: @product,
                         quantity: 10, unit_price: 1_000, issue: true)

      CreditNoteCreator.new(sale: sale, user: @user, params: {
        items: [{ product_id: @product.id, quantity: 4 }]
      }).call
      assert_not sale.reload.annulled?

      CreditNoteCreator.new(sale: sale, user: @user, params: {
        items: [{ product_id: @product.id, quantity: 6 }]
      }).call

      assert sale.reload.annulled?
      assert_equal 50, level
    end

    test "no se puede devolver mas de lo vendido" do
      sale = create_sale(company: @company, user: @user, product: @product,
                         quantity: 5, unit_price: 1_000, issue: true)

      error = assert_raises(InventoryManager::Error) do
        CreditNoteCreator.new(sale: sale, user: @user, params: {
          items: [{ product_id: @product.id, quantity: 99 }]
        }).call
      end
      assert_includes error.message, "quedan 5 unidades"
    end

    test "no se puede anular dos veces" do
      sale = create_sale(company: @company, user: @user, product: @product, issue: true)
      CreditNoteCreator.new(sale: sale, user: @user).call

      error = assert_raises(InventoryManager::Error) do
        CreditNoteCreator.new(sale: sale, user: @user).call
      end
      assert_includes error.message, "ya fue anulado"
    end

    test "no se puede anular un documento sin emitir" do
      sale = create_sale(company: @company, user: @user, product: @product, issue: false)

      error = assert_raises(InventoryManager::Error) do
        CreditNoteCreator.new(sale: sale, user: @user).call
      end
      assert_includes error.message, "documento emitido"
    end

    test "no se corrige una nota de credito con otra" do
      sale = create_sale(company: @company, user: @user, product: @product, issue: true)
      note = CreditNoteCreator.new(sale: sale, user: @user).call

      assert_raises(InventoryManager::Error) do
        CreditNoteCreator.new(sale: note, user: @user).call
      end
    end

    test "la nota de credito hereda el receptor del documento original" do
      customer = create_customer(@company)
      sale = create_sale(company: @company, user: @user, product: @product,
                         document_type: "factura", customer: customer, issue: true)

      note = CreditNoteCreator.new(sale: sale, user: @user).call

      assert_equal customer.id, note.customer_id
    end
  end
end
