require "test_helper"

# Un folio duplicado es un documento tributario invalido. El SELECT ... FOR
# UPDATE de CafRange.assign_folio! es lo que lo impide, y esta es la prueba que
# lo respalda.
#
# Va en su propia clase con `use_transactional_tests = false` porque los hilos
# usan conexiones distintas: dentro de la transaccion de test no verian los
# datos sin commitear y se bloquearian esperandola. La contrapartida es que hay
# que limpiar a mano.
class CafRangeConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  # El pool por defecto es 5 conexiones; se dejan 4 hilos para no agotarlo con
  # el de la propia prueba.
  THREADS = 4

  setup do
    @company = create_company(name: "Concurrencia SpA")
    @range = create_caf_range(@company, document_type: 39, range_start: 1, range_end: 100)
  end

  teardown do
    CafRange.where(company_id: @company.id).delete_all
    Store.where(company_id: @company.id).delete_all
    Company.where(id: @company.id).delete_all
  end

  test "no entrega folios duplicados ni deja huecos" do
    folios = []
    mutex = Mutex.new

    threads = THREADS.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          folio, = CafRange.assign_folio!(company: @company, document_type: 39)
          mutex.synchronize { folios << folio }
        end
      end
    end
    threads.each { |thread| thread.join(30) }

    assert_equal THREADS, folios.size, "algun hilo no completo su asignacion"
    assert_equal THREADS, folios.uniq.size, "folios duplicados: #{folios.sort.inspect}"
    assert_equal (1..THREADS).to_a, folios.sort, "huecos en la numeracion"
    assert_equal THREADS + 1, @range.reload.next_folio
  end
end
