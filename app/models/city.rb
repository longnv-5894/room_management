class City < ApplicationRecord
  belongs_to :country
  has_many :districts, dependent: :destroy
  has_many :buildings
  
  validates :name, presence: true
  validates :name, uniqueness: { scope: :country_id }
end
