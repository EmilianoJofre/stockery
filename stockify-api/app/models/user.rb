class User < ApplicationRecord
  has_secure_password

  has_many :inventory_adjustments
  has_many :purchases
  has_many :sales

  enum role: { admin: 0, manager: 1, clerk: 2 }

  before_validation :normalize_email

  validates :name, :email, :role, presence: true
  validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
