class User < ApplicationRecord
  has_secure_password
  has_many :buildings, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }, on: :create
  validates :name, presence: true

  # For handling profile image
  has_one_attached :profile_image

  # Gender constants
  GENDERS = [ "male", "female", "other" ]

  # Additional attribute validations
  validates :gender, inclusion: { in: GENDERS }, allow_blank: true
  validates :phone, format: { with: /\A[\d\-\+\s\.]+\z/ }, allow_blank: true
  validates :id_number, uniqueness: true, allow_blank: true
  validates :id_issue_place, presence: false, allow_blank: true
  validates :id_issue_date, presence: false, allow_blank: true

  def display_name
    name.presence || email.split("@").first
  end

  def age
    return nil unless date_of_birth.present?
    now = Time.now.utc.to_date
    now.year - date_of_birth.year - (date_of_birth.to_date.change(year: now.year) > now ? 1 : 0)
  end
end
