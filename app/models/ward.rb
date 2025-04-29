class Ward < ApplicationRecord
  belongs_to :district
  has_many :buildings
  
  validates :name, presence: true
  validates :name, uniqueness: { scope: :district_id }
end
