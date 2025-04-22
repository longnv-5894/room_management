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
                                 :room_fee, :electricity_fee, :water_fee, 
                                 :other_fees, :notes, :status)
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t('auth.login_required')
      redirect_to login_path
    end
  end
end
