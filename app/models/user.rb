class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :group
  has_many :projects, through: :group

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
