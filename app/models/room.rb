class Room < ApplicationRecord
  has_many :room_assignments
  has_many :tenants, through: :room_assignments
  has_many :utility_readings
  
  validates :number, presence: true, uniqueness: true
  validates :monthly_rent, presence: true, numericality: { greater_than: 0 }
  
  enum :status, { available: 'available', occupied: 'occupied', maintenance: 'maintenance' }
  
  def current_assignments
    room_assignments.where(active: true)
  end
  
  def current_assignment
    current_assignments.first
  end
  
  def current_tenant
    current_assignment&.tenant
  end
  
  def current_tenants
    tenants.joins(:room_assignments).where(room_assignments: { active: true, room_id: id })
  end
  
  def occupied?
    status == 'occupied'
  end
  
  def bills
    Bill.joins(:room_assignment).where(room_assignments: { room_id: id }).order(billing_date: :desc)
  end
end
