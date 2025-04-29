class District < ApplicationRecord
  belongs_to :city
  has_many :wards, dependent: :destroy
  has_many :buildings
  
  validates :name, presence: true
  validates :name, uniqueness: { scope: :city_id }
end
