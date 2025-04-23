class BillsController < ApplicationController
  before_action :require_login
  before_action :set_bill, only: [:show, :edit, :update, :destroy, :mark_as_paid]

  def index
    @bills = Bill.includes(room_assignment: [:room, :tenant]).order(billing_date: :desc)
  end

  def show
    @room_assignment = @bill.room_assignment
    @tenant = @room_assignment.tenant
    @room = @room_assignment.room
  end

  def new
    @bill = Bill.new
    @active_assignments = RoomAssignment.where(active: true).includes(:room, :tenant)
    
    # If room_assignment_id is provided, pre-load the utility readings
    if params[:room_assignment_id].present?
      @room_assignment = RoomAssignment.includes(:room, :tenant).find(params[:room_assignment_id])
      @room = @room_assignment.room
      @latest_readings = UtilityReading.where(room_id: @room.id).order(reading_date: :desc).limit(2)
      
      # Initialize bill with room assignment and default values
      @bill.room_assignment_id = @room_assignment.id
      @bill.room_fee = @room.monthly_rent
      
      # Set default service fee from the latest reading if available
      if @latest_readings.present? && @latest_readings.first.respond_to?(:service_charge)
        @bill.service_fee = @latest_readings.first.service_charge
      end
    end
  end

  def create
    @bill = Bill.new(bill_params)

    if @bill.save
      flash[:success] = t('bills.create_success')
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
      flash[:success] = t('bills.update_success')
      redirect_to @bill
    else
      @room_assignments = RoomAssignment.includes(:room, :tenant)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bill.destroy
    flash[:success] = t('bills.delete_success')
    redirect_to bills_url
  end

  def mark_as_paid
    @bill.update(status: "paid")
    flash[:success] = t('bills.mark_paid_success')
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
      flash[:danger] = t('auth.login_required')
      redirect_to login_path
    end
  end
end
