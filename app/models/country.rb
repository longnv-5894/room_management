class Country < ApplicationRecord
  has_many :cities, dependent: :destroy
  has_many :buildings
  
  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
end
