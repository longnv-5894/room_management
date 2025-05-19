class Bill < ApplicationRecord
  belongs_to :room_assignment

  validates :billing_date, presence: true
  validates :due_date, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }

  # Đảm bảo các giá trị thanh toán là hợp lệ
  validates :paid_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :remaining_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Tự động cập nhật số tiền còn thiếu khi lưu
  before_save :update_remaining_amount

  enum :status, { unpaid: "unpaid", partial: "partial", paid: "paid" }, prefix: true

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
    # Cập nhật số tiền đã thanh toán và còn thiếu
    update(
      status: "paid",
      paid_amount: total_amount,
      remaining_amount: 0
    )

    # Thêm vào lịch sử thanh toán
    payment_records = payment_history_json || []
    payment_records << {
      date: Date.today,
      amount: total_amount - (paid_amount || 0),
      note: "Đánh dấu là đã thanh toán đủ"
    }
    update(payment_history: payment_records.to_json)

    # When one tenant pays, mark all other tenants' bills for the same room and period as paid
    mark_other_tenant_bills_as_paid if status == "paid"
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
    updated_at if status == "paid"
  end

  # Phương thức thanh toán một phần
  def record_payment(amount)
    return false if amount <= 0

    # Chuyển đổi sang decimal để đảm bảo tính toán chính xác
    amount = amount.to_d

    # Tính toán số tiền đã thanh toán mới và số tiền còn lại
    new_paid_amount = paid_amount + amount
    new_remaining_amount = total_amount - new_paid_amount

    # Cập nhật lịch sử thanh toán
    payment_records = payment_history_json || []
    payment_records << {
      date: Date.today,
      amount: amount,
      note: "Thanh toán hóa đơn"
    }

    # Cập nhật trạng thái thanh toán
    new_status = if new_paid_amount >= total_amount
                  "paid"
    elsif new_paid_amount > 0
                  "partial"
    else
                  "unpaid"
    end

    # Lưu các thay đổi
    update(
      paid_amount: new_paid_amount,
      remaining_amount: new_remaining_amount,
      status: new_status,
      payment_history: payment_records.to_json
    )
  end

  # Lấy lịch sử thanh toán dưới dạng mảng các hash
  def payment_history_json
    return [] if payment_history.blank?

    begin
      JSON.parse(payment_history)
    rescue JSON::ParserError
      []
    end
  end

  # Phương thức hoàn tiền
  def refund(amount)
    return false if amount <= 0 || paid_amount < amount

    # Chuyển đổi sang decimal để đảm bảo tính toán chính xác
    amount = amount.to_d

    # Tính toán số tiền đã thanh toán mới và số tiền còn lại
    new_paid_amount = paid_amount - amount
    new_remaining_amount = total_amount - new_paid_amount

    # Cập nhật lịch sử thanh toán
    payment_records = payment_history_json || []
    payment_records << {
      date: Date.today,
      amount: -amount,
      note: "Hoàn tiền"
    }

    # Cập nhật trạng thái thanh toán
    new_status = if new_paid_amount >= total_amount
                  "paid"
    elsif new_paid_amount > 0
                  "partial"
    else
                  "unpaid"
    end

    # Lưu các thay đổi
    update(
      paid_amount: new_paid_amount,
      remaining_amount: new_remaining_amount,
      status: new_status,
      payment_history: payment_records.to_json
    )
  end

  # Kiểm tra xem hóa đơn đã thanh toán đủ chưa
  def fully_paid?
    paid_amount >= total_amount
  end

  # Kiểm tra xem hóa đơn đã thanh toán một phần chưa
  def partially_paid?
    paid_amount > 0 && paid_amount < total_amount
  end

  # Tính tổng nợ của người thuê
  def self.total_debt_for_tenant(tenant)
    joins(:room_assignment)
      .where(room_assignments: { tenant_id: tenant.id })
      .where.not(status: "paid")
      .sum(:remaining_amount)
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
                  .where("reading_date BETWEEN ? AND ?", start_date, end_date)
                  .order(reading_date: :desc)
  end

  # Get the latest utility reading for the room at billing time
  def latest_utility_reading
    return nil unless room

    UtilityReading.where(room_id: room.id)
                  .where("reading_date <= ?", billing_date)
                  .order(reading_date: :desc)
                  .first
  end

  private

  def calculate_total
    service_fee_value = respond_to?(:service_fee) ? service_fee : 0
    prev_debt_value = respond_to?(:previous_debt) ? previous_debt : 0
    overpayment_value = respond_to?(:overpayment) ? overpayment : 0

    # Tổng tiền = tiền phòng + tiền điện + tiền nước + phí dịch vụ + nợ cũ - thừa + phí khác
    self.total_amount = room_fee + electricity_fee + water_fee +
                        service_fee_value + prev_debt_value - overpayment_value + other_fees
  end

  # Apply payment schedule rules to determine which fees to include in this bill
  def apply_payment_schedule
    # Handle room fee based on frequency
    if should_include_room_fee?
      # If this is a billing month for room fee, multiply by frequency
      room_fee_frequency = room_assignment.effective_room_fee_frequency

      # Lấy giá phòng từ room_assignment thay vì từ room
      assignment_rent = room_assignment.monthly_rent

      # Only multiply if frequency is > 1 and we're using the default room fee
      if room_fee_frequency > 1 && self.room_fee == assignment_rent
        self.room_fee = assignment_rent * room_fee_frequency
      end
    else
      # Zero out the room fee if it shouldn't be included this month
      self.room_fee = 0
    end

    # Handle utility fees based on frequency
    if should_include_utility_fee?
      # If this is a billing month for utilities, we leave the fees as is
      # Utility readings are typically based on actual usage, so we don't multiply them
    else
      # Zero out utility fees if they shouldn't be included this month
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
                        .where("extract(month from billing_date) = ?", billing_date.month)
                        .where("extract(year from billing_date) = ?", billing_date.year)
                        .where.not(status: "paid")

      # Mark as paid
      other_bills.update_all(status: "paid")
    end
  end

  def update_remaining_amount
    # Chỉ cập nhật remaining_amount khi paid_amount có giá trị
    if self.paid_amount.present?
      self.remaining_amount = self.total_amount - self.paid_amount
    end
  end
end
