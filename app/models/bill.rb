class Bill < ApplicationRecord
  belongs_to :room_assignment
  
  validates :billing_date, presence: true
  validates :due_date, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
  
  enum :status, { unpaid: 'unpaid', partial: 'partial', paid: 'paid' }, prefix: true
  
  before_save :calculate_total
  before_validation :apply_payment_schedule, on: :create
  
  def tenant
    room_assignment.tenant
  end
  
  def room
    room_assignment.room
  end
  
  # Check if room fee should be included in this month's bill
  def should_include_room_fee?
    # Get the room fee frequency directly from room_assignment
    room_fee_frequency = room_assignment.effective_room_fee_frequency
    
    # Get the month number (1-12) in the year
    month_in_year = billing_date.month
    
    # Room fee should be included if the month is divisible by the frequency
    # Example: For quarterly payments (frequency=3), months 3,6,9,12 would return true
    month_in_year % room_fee_frequency == 0
  end
  
  # Check if utility fee should be included in this month's bill
  def should_include_utility_fee?
    # Get the utility fee frequency directly from room_assignment
    utility_fee_frequency = room_assignment.effective_utility_fee_frequency
    
    # Get the month number (1-12) in the year
    month_in_year = billing_date.month
    
    # Utility fee should be included if the month is divisible by the frequency
    month_in_year % utility_fee_frequency == 0
  end
  
  def mark_as_paid
    update(status: 'paid')
    # When one tenant pays, mark all other tenants' bills for the same room and period as paid
    mark_other_tenant_bills_as_paid if status == 'paid'
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
  
  # Apply payment schedule rules to determine which fees to include in this bill
  def apply_payment_schedule
    # Zero out the room fee if it shouldn't be included this month
    unless should_include_room_fee?
      self.room_fee = 0
    end
    
    # Zero out utility fees if they shouldn't be included this month
    unless should_include_utility_fee?
      self.electricity_fee = 0
      self.water_fee = 0
      self.service_fee = 0 if respond_to?(:service_fee)
    end
  end
  
  # Mark all bills for other tenants in the same room for the same period as paid
  def mark_other_tenant_bills_as_paid
    return unless room && billing_date
    
    # Find all active room assignments for this room
    room_assignments = room.room_assignments.where(active: true)
    
    # Find and mark bills for other tenants in the same room for the same billing period
    room_assignments.each do |assignment|
      next if assignment.id == room_assignment_id # Skip current tenant's bill
      
      # Find bills for the same month
      other_bills = Bill.where(room_assignment_id: assignment.id)
                        .where('extract(month from billing_date) = ?', billing_date.month)
                        .where('extract(year from billing_date) = ?', billing_date.year)
                        .where.not(status: 'paid')
      
      # Mark as paid
      other_bills.update_all(status: 'paid')
    end
  end
end
