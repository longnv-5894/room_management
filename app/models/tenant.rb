class Tenant < ApplicationRecord
  has_many :room_assignments
  has_many :rooms, through: :room_assignments
  
  validates :name, presence: true
  validates :id_number, presence: true, uniqueness: true
  
  def current_room_assignment
    room_assignments.where(active: true).first
  end
  
  def current_room
    current_room_assignment&.room
  end
end
