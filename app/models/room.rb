class Room < ApplicationRecord
  has_many :room_assignments
  has_many :tenants, through: :room_assignments
  has_many :utility_readings
  
  validates :number, presence: true, uniqueness: true
  validates :monthly_rent, presence: true, numericality: { greater_than: 0 }
  
  enum :status, { available: 'available', occupied: 'occupied', maintenance: 'maintenance' }
  
  def current_assignment
    room_assignments.where(active: true).first
  end
  
  def current_tenant
    current_assignment&.tenant
  end
  
  def occupied?
    status == 'occupied'
  end
end
