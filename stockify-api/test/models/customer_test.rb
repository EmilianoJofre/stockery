require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  setup { @company = create_company }

  # Digito verificador chileno (modulo 11).
  test "calcula el digito verificador" do
    assert_equal "9", Customer.rut_check_digit("76192083")
    assert_equal "3", Customer.rut_check_digit("5126663")
    assert_equal "4", Customer.rut_check_digit("9678245")
  end

  test "normaliza el RUT quitando puntos y dejando el guion" do
    assert_equal "76192083-9", Customer.new(rut: "76.192.083-9").tap(&:normalize_rut).rut
    assert_equal "76192083-9", Customer.new(rut: "761920839").tap(&:normalize_rut).rut
    assert_equal "12345678-K", Customer.new(rut: "12.345.678-k").tap(&:normalize_rut).rut
  end

  test "rechaza un digito verificador invalido" do
    customer = @company.customers.build(rut: "76192083-5", name: "RUT malo")

    assert_not customer.valid?
    assert_includes customer.errors[:rut].join, "digito verificador"
  end

  test "acepta un cliente sin RUT" do
    assert @company.customers.build(name: "Mostrador").valid?
  end

  test "el RUT es unico por compania pero no entre companias" do
    create_customer(@company, rut: "76192083-9")
    duplicate = @company.customers.build(rut: "76192083-9", name: "Otro")
    assert_not duplicate.valid?

    otra = create_company(name: "Otra SpA")
    assert otra.customers.build(rut: "76192083-9", name: "Mismo RUT").valid?
  end

  test "formatea el RUT con puntos" do
    assert_equal "76.192.083-9", create_customer(@company, rut: "76192083-9").formatted_rut
  end
end
