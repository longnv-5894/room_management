class UtilityReading < ApplicationRecord
  belongs_to :room
  
  validates :reading_date, presence: true
  validates :electricity_reading, numericality: { greater_than_or_equal_to: 0 }
  validates :water_reading, numericality: { greater_than_or_equal_to: 0 }
  
  # Find related bills that might include this reading
  def related_bills
    # Look for bills in the same month or the following month (since readings are often taken at month's end)
    start_date = reading_date.beginning_of_month
    end_date = (reading_date + 1.month).end_of_month
    
    Bill.joins(room_assignment: :room)
        .where('rooms.id = ?', room_id)
        .where('bills.billing_date BETWEEN ? AND ?', start_date, end_date)
        .order(billing_date: :desc)
  end
  
  # Find active room assignments for this room at the time of the reading
  def active_room_assignments
    room.room_assignments.where('start_date <= ? AND (end_date IS NULL OR end_date >= ?)', 
                               reading_date, reading_date)
  end
  
  def previous_reading
    UtilityReading.where(room_id: room_id)
                  .where('reading_date < ?', reading_date)
                  .order(reading_date: :desc)
                  .first
  end
  
  def electricity_usage
    prev = previous_reading
    prev ? [electricity_reading - prev.electricity_reading, 0].max : 0
  end
  
  def water_usage
    prev = previous_reading
    prev ? [water_reading - prev.water_reading, 0].max : 0
  end
  
  # Use the utility price configuration from the date of the reading
  def utility_price
    @utility_price ||= UtilityPrice.for_date(reading_date)
  end
  
  def electricity_unit_price
    utility_price.electricity_unit_price
  end
  
  def water_unit_price
    utility_price.water_unit_price
  end
  
  def electricity_cost
    electricity_usage * electricity_unit_price
  end
  
  def water_cost
    water_usage * water_unit_price
  end
  
  def service_charge
    utility_price.service_charge
  end
  
  def service_charge_cost
    # Find active tenant count for this room at the time of the reading
    tenant_count = room.room_assignments.where('start_date <= ? AND (end_date IS NULL OR end_date >= ?)', 
                                             reading_date, reading_date)
                                         .count
    
    # Calculate service charge based on tenant count
    tenant_count * service_charge
  end
  
  def total_cost
    electricity_cost + water_cost + service_charge_cost
  end
end
