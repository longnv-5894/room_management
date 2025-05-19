class BillsController < ApplicationController
  before_action :require_login
  before_action :set_bill, only: [ :show, :edit, :update, :destroy, :mark_as_paid, :record_payment ]

  def index
    # Get all bills
    bills_query = Bill.includes(room_assignment: [ :room, :tenant ]).order(billing_date: :desc)

    # Apply filters
    if params[:building_id].present?
      building_id = params[:building_id]
      bills_query = bills_query.joins(room_assignment: :room)
                              .where(room_assignments: { rooms: { building_id: building_id } })
    end

    if params[:room_id].present?
      room_id = params[:room_id]
      bills_query = bills_query.joins(:room_assignment)
                              .where(room_assignments: { room_id: room_id })
    end

    if params[:status].present?
      bills_query = bills_query.where(status: params[:status])
    end

    if params[:date_from].present?
      date_from = Date.parse(params[:date_from])
      bills_query = bills_query.where("billing_date >= ?", date_from)
    end

    if params[:date_to].present?
      date_to = Date.parse(params[:date_to])
      bills_query = bills_query.where("billing_date <= ?", date_to)
    end

    bills = bills_query

    # Group bills by room and billing period
    @room_bills = {}

    bills.each do |bill|
      room = bill.room_assignment.room
      billing_period = "#{bill.billing_date.year}-#{bill.billing_date.month}"

      @room_bills[[ room.id, billing_period ]] ||= {
        room: room,
        bills: [],
        billing_date: bill.billing_date,
        billing_period_start: bill.billing_period_start,
        billing_period_end: bill.billing_period_end,
        due_date: bill.due_date,
        tenants: [],
        total_amount: bill.total_amount,
        rent_amount: bill.rent_amount,
        utility_amount: bill.utility_amount,
        paid_amount: bill.paid_amount,
        remaining_amount: bill.remaining_amount,
        status: bill.status,
        representative_bill: bill.room_assignment.is_representative_tenant ? bill : nil # Use bill for representative tenant if available
      }

      @room_bills[[ room.id, billing_period ]][:bills] << bill
      @room_bills[[ room.id, billing_period ]][:tenants] << bill.room_assignment.tenant

      # If this bill is for the representative tenant, use it as the representative_bill
      if bill.room_assignment.is_representative_tenant
        @room_bills[[ room.id, billing_period ]][:representative_bill] = bill
      end
    end

    # If no representative tenant bill found, use the first bill as fallback
    @room_bills.each do |_, room_bill|
      room_bill[:representative_bill] ||= room_bill[:bills].first
    end

    # Convert the hash to an array
    @room_bills = @room_bills.values
  end

  def show
    @room_assignment = @bill.room_assignment
    @tenant = @room_assignment.tenant
    @room = @room_assignment.room

    # Get all active room assignments for this room
    @room_assignments = @room.room_assignments.where(active: true).includes(:tenant)

    # Get all the bills for the same room and billing period
    @related_bills = Bill.joins(:room_assignment)
                        .where(room_assignments: { room_id: @room.id })
                        .where("extract(month from billing_date) = ?", @bill.billing_date.month)
                        .where("extract(year from billing_date) = ?", @bill.billing_date.year)
                        .includes(room_assignment: :tenant)

    # Get utility readings for this bill's period
    @utility_readings = @bill.relevant_utility_readings

    respond_to do |format|
      format.html
      format.pdf do
        # Explicitly specify HTML format to bypass locale-specific lookup
        html = render_to_string(
          partial: "bill_pdf",
          formats: [ :html ],
          handlers: [ :erb ],
          locals: { bill: @bill, tenant: @tenant, room: @room, utility_readings: @utility_readings, room_assignments: @room_assignments },
          layout: false
        )

        pdf = WickedPdf.new.pdf_from_string(
          html,
          page_size: "A4",
          encoding: "UTF-8"
        )

        send_data pdf, filename: "bill_#{@bill.id}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  def new
    @bill = Bill.new
    @active_assignments = RoomAssignment.where(active: true).includes(:room, :tenant)

    # If room_assignment_id is provided, pre-load the utility readings
    if params[:room_assignment_id].present?
      @room_assignment = RoomAssignment.includes(:room, :tenant).find(params[:room_assignment_id])
      @room = @room_assignment.room
      @latest_readings = UtilityReading.where(room_id: @room.id).order(reading_date: :desc).limit(2)

      # Initialize bill with room assignment
      @bill.room_assignment_id = @room_assignment.id

      # Get the room fee frequency
      room_fee_frequency = @room_assignment.effective_room_fee_frequency

      # Check if this month should include room fee based on frequency
      billing_month = Date.today.month
      include_room_fee = (billing_month % room_fee_frequency == 0)

      # Set appropriate room fee
      if include_room_fee
        # Lấy giá phòng từ room_assignment thay vì room
        @bill.room_fee = room_fee_frequency > 1 ? @room_assignment.monthly_rent * room_fee_frequency : @room_assignment.monthly_rent
      else
        @bill.room_fee = 0
      end

      # Set default service fee from the latest reading if available
      if @latest_readings.present? && @latest_readings.first.respond_to?(:service_charge)
        @bill.service_fee = @latest_readings.first.service_charge
      end
    end
  end

  def create
    @bill = Bill.new(bill_params)

    if @bill.save
      flash[:success] = t("bills.create_success")
      redirect_to @bill
    else
      @active_assignments = RoomAssignment.where(active: true).includes(:room, :tenant)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @room_assignments = RoomAssignment.includes(:room, :tenant)
  end

  def update
    if @bill.update(bill_params)
      flash[:success] = t("bills.update_success")
      redirect_to @bill
    else
      @room_assignments = RoomAssignment.includes(:room, :tenant)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bill.destroy
    flash[:success] = t("bills.delete_success")
    redirect_to bills_url
  end

  def mark_as_paid
    @bill.mark_as_paid
    flash[:success] = t("bills.mark_paid_success")
    redirect_to @bill
  end

  def record_payment
    @bill = Bill.find(params[:id])
    amount = params[:amount].to_f

    if amount <= 0
      flash[:danger] = t("bills.invalid_payment_amount")
      redirect_to @bill
      return
    end

    if @bill.record_payment(amount)
      flash[:success] = t("bills.payment_recorded_success")
    else
      flash[:danger] = t("bills.payment_record_failed")
    end

    redirect_to @bill
  end

  private

  def set_bill
    @bill = Bill.find(params[:id])
  end

  def bill_params
    params.require(:bill).permit(:room_assignment_id, :billing_date, :due_date,
                                 :room_fee, :electricity_fee, :water_fee, :service_fee,
                                 :other_fees, :notes, :status)
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t("auth.login_required")
      redirect_to login_path
    end
  end
end
