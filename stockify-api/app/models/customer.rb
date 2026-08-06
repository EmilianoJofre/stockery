class Customer < ApplicationRecord
  belongs_to :company
  has_many :sales, dependent: :nullify

  before_validation :normalize_rut

  validates :name, presence: true
  validates :rut, uniqueness: { scope: :company_id, allow_nil: true }
  validate  :rut_must_be_valid

  scope :active, -> { where(active: true) }

  # RUT normalizado a "12345678-9" (sin puntos, digito verificador en mayuscula).
  def normalize_rut
    return if rut.blank?

    digits = rut.to_s.upcase.gsub(/[^0-9K]/, "")
    if digits.length < 2
      self.rut = digits
      return
    end

    self.rut = "#{digits[0..-2]}-#{digits[-1]}"
  end

  # Digito verificador chileno (modulo 11).
  def self.rut_check_digit(body)
    sum = 0
    factor = 2

    body.to_s.reverse.each_char do |char|
      sum += char.to_i * factor
      factor = factor == 7 ? 2 : factor + 1
    end

    remainder = 11 - (sum % 11)
    case remainder
    when 11 then "0"
    when 10 then "K"
    else remainder.to_s
    end
  end

  def formatted_rut
    return nil if rut.blank?

    body, check = rut.split("-")
    "#{body.to_s.reverse.scan(/\d{1,3}/).join('.').reverse}-#{check}"
  end

  private

  def rut_must_be_valid
    return if rut.blank?

    body, check = rut.split("-")

    if body.blank? || check.blank? || !body.match?(/\A\d+\z/)
      errors.add(:rut, "no tiene un formato valido (ej. 12345678-9)")
      return
    end

    return if self.class.rut_check_digit(body) == check

    errors.add(:rut, "tiene un digito verificador invalido")
  end
end
