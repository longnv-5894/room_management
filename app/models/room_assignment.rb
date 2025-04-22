class RoomAssignment < ApplicationRecord
  belongs_to :room
  belongs_to :tenant
  has_many :bills
  
  validates :start_date, presence: true
  validate :end_date_after_start_date, if: -> { end_date.present? }
  validate :no_active_assignment_for_room, if: :active?
  
  before_save :update_room_status
  
  # Used for displaying in select dropdowns
  def display_name
    "Room #{room.number} - #{tenant.name}"
  end
  
  private
  
  def end_date_after_start_date
    if end_date <= start_date
      errors.add(:end_date, "must be after the start date")
    end
  end
  
  def no_active_assignment_for_room
    other_assignments = room.room_assignments.where(active: true)
    other_assignments = other_assignments.where.not(id: id) if persisted?
    
    if other_assignments.exists?
      errors.add(:room_id, "already has an active tenant")
    end
  end
  
  def update_room_status
    if active?
      room.update(status: 'occupied')
    elsif room.room_assignments.where(active: true).where.not(id: id).empty?
      room.update(status: 'available')
    end
  end
end
