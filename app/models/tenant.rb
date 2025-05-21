class Tenant < ApplicationRecord
  has_many :room_assignments
  has_many :rooms, through: :room_assignments
  has_many :vehicles, dependent: :destroy
  has_many :device_users, dependent: :nullify

  validates :name, presence: true
  validates :id_number, presence: true, uniqueness: true

  def current_room_assignments
    room_assignments.where(active: true)
  end

  def current_room_assignment
    current_room_assignments.first
  end

  def current_rooms
    rooms.joins(:room_assignments).where(room_assignments: { active: true, tenant_id: id })
  end

  def current_room
    current_room_assignment&.room
  end

  def has_active_assignment
    current_room_assignments.exists?
  end
end
