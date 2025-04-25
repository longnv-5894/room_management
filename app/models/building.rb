class Building < ApplicationRecord
  belongs_to :user
  has_many :rooms, dependent: :destroy
  
  validates :name, presence: true
  validates :address, presence: true
  
  # Building status options
  STATUSES = ['active', 'under_construction', 'renovation', 'inactive'].freeze
  
  enum :status, STATUSES.zip(STATUSES).to_h, default: 'active'
  
  # Return translated statuses for select options
  def self.statuses_for_select
    STATUSES.map { |key| [I18n.t("buildings.statuses.#{key}"), key] }
  end
  
  # Return total number of rooms
  def total_rooms
    rooms.count
  end
  
  # Return total number of tenants
  def total_tenants
    rooms.joins(:room_assignments).where(room_assignments: { active: true }).count
  end
  
  # Return occupancy rate
  def occupancy_rate
    return 0 if total_rooms == 0
    (rooms.where(status: 'occupied').count.to_f / total_rooms) * 100
  end
  
  # Return total monthly revenue potential
  def total_monthly_revenue_potential
    rooms.sum(:monthly_rent)
  end
  
  # Return actual monthly revenue
  def actual_monthly_revenue
    rooms.where(status: 'occupied').sum(:monthly_rent)
  end
  
  def operating_expenses
    OperatingExpense.where(building_id: id)
  end
end
