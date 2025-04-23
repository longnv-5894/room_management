class Bill < ApplicationRecord
  belongs_to :room_assignment
  
  validates :billing_date, presence: true
  validates :due_date, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
  
  enum :status, { unpaid: 'unpaid', partial: 'partial', paid: 'paid' }, prefix: true
  
  before_save :calculate_total
  
  def tenant
    room_assignment.tenant
  end
  
  def room
    room_assignment.room
  end
  
  def mark_as_paid
    update(status: 'paid')
  end
  
  # Calculate billing period (first day of the month to last day)
  def billing_period_start
    billing_date.beginning_of_month
  end
  
  def billing_period_end
    billing_date.end_of_month
  end
  
  # Virtual payment_date method - returns updated_at if status is paid, otherwise nil
  def payment_date
    updated_at if status == 'paid'
  end
  
  # Additional helper methods for view
  def rent_amount
    room_fee
  end
  
  def utility_amount
    electricity_fee + water_fee + (respond_to?(:service_fee) ? service_fee : 0)
  end
  
  def additional_charges
    other_fees
  end
  
  # Find utility readings relevant to this bill's period
  def relevant_utility_readings
    return [] unless room
    
    # Find readings within or close to the billing period
    start_date = billing_period_start - 5.days
    end_date = billing_period_end + 5.days
    
    UtilityReading.where(room_id: room.id)
                  .where('reading_date BETWEEN ? AND ?', start_date, end_date)
                  .order(reading_date: :desc)
  end
  
  # Get the latest utility reading for the room at billing time
  def latest_utility_reading
    return nil unless room
    
    UtilityReading.where(room_id: room.id)
                  .where('reading_date <= ?', billing_date)
                  .order(reading_date: :desc)
                  .first
  end
  
  private
  
  def calculate_total
    service_fee_value = respond_to?(:service_fee) ? service_fee : 0
    self.total_amount = room_fee + electricity_fee + water_fee + service_fee_value + other_fees
  end
end
