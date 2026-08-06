ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |file| require file }

module ActiveSupport
  class TestCase
    # Sin paralelizacion: la prueba de folios concurrentes necesita hilos reales
    # sobre una misma base, y los workers en procesos separados la invalidarian.
    parallelize(workers: 1)

    include Scenario
  end
end
