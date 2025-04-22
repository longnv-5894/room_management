class RoomAssignmentsController < ApplicationController
  before_action :require_login
  before_action :set_room_assignment, only: [:show, :edit, :update, :destroy, :end]

  def index
    @room_assignments = RoomAssignment.includes(:room, :tenant).order(created_at: :desc)
  end

  def show
    @bills = @room_assignment.bills.order(billing_date: :desc)
  end

  def new
    @room_assignment = RoomAssignment.new
    @available_rooms = Room.where(status: 'available')
    @available_tenants = Tenant.all
  end

  def create
    @room_assignment = RoomAssignment.new(room_assignment_params)

    if @room_assignment.save
      # Set the room as occupied
      @room_assignment.room.update(status: 'occupied')
      
      flash[:success] = t('room_assignments.create_success')
      redirect_to @room_assignment
    else
      @available_rooms = Room.where(status: 'available')
      @available_tenants = Tenant.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_rooms = Room.where(status: 'available')
    @available_rooms = @available_rooms.or(Room.where(id: @room_assignment.room_id))
    @available_tenants = Tenant.all
  end

  def update
    if @room_assignment.update(room_assignment_params)
      flash[:success] = t('room_assignments.update_success')
      redirect_to @room_assignment
    else
      @available_rooms = Room.where(status: 'available')
      @available_rooms = @available_rooms.or(Room.where(id: @room_assignment.room_id))
      @available_tenants = Tenant.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @room_assignment.bills.exists?
      flash[:danger] = t('room_assignments.cannot_delete_with_bills')
      redirect_to room_assignments_url
    else
      @room_assignment.update(active: false, end_date: Date.today)
      @room_assignment.room.update(status: 'available')
      flash[:success] = t('room_assignments.end_success')
      redirect_to room_assignments_url
    end
  end
  
  def end
    if @room_assignment.update(active: false, end_date: Date.today)
      # Also update the room status to available
      @room_assignment.room.update(status: 'available')
      
      flash[:success] = t('room_assignments.end_success')
      redirect_to room_assignments_path
    else
      flash[:danger] = t('room_assignments.end_error')
      redirect_to room_assignments_path
    end
  end

  private

  def set_room_assignment
    @room_assignment = RoomAssignment.find(params[:id])
  end

  def room_assignment_params
    params.require(:room_assignment).permit(:room_id, :tenant_id, :start_date, 
                                            :end_date, :deposit_amount, :active)
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t('auth.login_required')
      redirect_to login_path
    end
  end
end
