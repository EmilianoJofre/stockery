require "test_helper"

class CafRangeTest < ActiveSupport::TestCase
  setup do
    @company = create_company
    @range = create_caf_range(@company, document_type: 39, range_start: 1, range_end: 5)
  end

  test "entrega folios consecutivos y avanza el rango" do
    folios = 3.times.map { CafRange.assign_folio!(company: @company, document_type: 39).first }

    assert_equal [1, 2, 3], folios
    assert_equal 4, @range.reload.next_folio
  end

  test "falla cuando el rango se agota" do
    5.times { CafRange.assign_folio!(company: @company, document_type: 39) }

    assert @range.reload.exhausted?
    error = assert_raises(CafRange::Exhausted) do
      CafRange.assign_folio!(company: @company, document_type: 39)
    end
    assert_includes error.message, "No hay folios disponibles"
  end

  test "ignora rangos vencidos" do
    @range.update!(expires_on: Date.current - 1)

    assert_raises(CafRange::Exhausted) do
      CafRange.assign_folio!(company: @company, document_type: 39)
    end
  end

  test "ignora rangos inactivos" do
    @range.update!(active: false)

    assert_raises(CafRange::Exhausted) do
      CafRange.assign_folio!(company: @company, document_type: 39)
    end
  end

  test "no mezcla folios entre tipos de documento" do
    create_caf_range(@company, document_type: 33, range_start: 500, range_end: 510)

    boleta, = CafRange.assign_folio!(company: @company, document_type: 39)
    factura, = CafRange.assign_folio!(company: @company, document_type: 33)

    assert_equal 1, boleta
    assert_equal 500, factura
  end

  test "valida que el rango este bien formado" do
    invalid = @company.caf_ranges.build(
      document_type: 39, range_start: 900, range_end: 100, next_folio: 900
    )

    assert_not invalid.valid?
    assert_includes invalid.errors[:range_end].join, "mayor o igual"
  end
end
