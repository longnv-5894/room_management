class RoomAssignmentsController < ApplicationController
  before_action :require_login
  before_action :set_room_assignment, only: [:show, :edit, :update, :destroy, :end]

  def index
    @room_assignments = RoomAssignment.includes(:room, :tenant).order(created_at: :desc)
  end

  def show
    @bills = @room_assignment.bills.order(billing_date: :desc)
    
    respond_to do |format|
      format.html # renders the default show.html.erb template
      format.json do
        render json: {
          id: @room_assignment.id,
          active: @room_assignment.active,
          start_date: @room_assignment.start_date,
          room: {
            id: @room_assignment.room.id,
            number: @room_assignment.room.number,
            monthly_rent: @room_assignment.room.monthly_rent,
            status: @room_assignment.room.status
          },
          tenant: {
            id: @room_assignment.tenant.id,
            name: @room_assignment.tenant.name,
            phone: @room_assignment.tenant.phone
          }
        }
      end
    end
  end

  def new
    @room_assignment = RoomAssignment.new
    
    # Pre-populate room_id if provided in the URL
    if params[:room_id].present?
      @room_assignment.room_id = params[:room_id]
    end
    
    # Include both available and occupied rooms (for adding additional tenants)
    @available_rooms = Room.where(status: ['available', 'occupied'])
    
    # Only show tenants who aren't already assigned to any room
    @available_tenants = Tenant.left_joins(:room_assignments)
                              .where('room_assignments.id IS NULL OR room_assignments.active = ?', false)
                              .distinct
  end

  def create
    @room_assignment = RoomAssignment.new(room_assignment_params)

    if @room_assignment.save
      # Set the room as occupied
      @room_assignment.room.update(status: 'occupied')
      
      flash[:success] = t('room_assignments.create_success')
      redirect_to @room_assignment
    else
      # Include both available and occupied rooms for rerendering the form
      @available_rooms = Room.where(status: ['available', 'occupied'])
      
      # Only show tenants who aren't already assigned to any room
      @available_tenants = Tenant.left_joins(:room_assignments)
                                .where('room_assignments.id IS NULL OR room_assignments.active = ?', false)
                                .distinct
      
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
