class RoomAssignmentsController < ApplicationController
  before_action :require_login
  before_action :set_room_assignment, only: [:show, :edit, :update, :destroy, :end]

  def index
    # Start with base query including related models
    @room_assignments = RoomAssignment.includes(:room, :tenant)
    
    # Apply room filter
    if params[:room_id].present?
      @room_assignments = @room_assignments.where(room_id: params[:room_id])
    end
    
    # Apply tenant filter
    if params[:tenant_id].present?
      @room_assignments = @room_assignments.where(tenant_id: params[:tenant_id])
    end
    
    # Apply status filter
    if params[:status].present?
      @room_assignments = @room_assignments.where(active: params[:status] == 'active')
    end
    
    # Apply date range filter for start_date
    if params[:start_date_from].present?
      @room_assignments = @room_assignments.where('start_date >= ?', params[:start_date_from])
    end
    
    if params[:start_date_to].present?
      @room_assignments = @room_assignments.where('start_date <= ?', params[:start_date_to])
    end
    
    # Get data for filter dropdowns
    @rooms = Room.order(:number)
    @tenants = Tenant.order(:name)
    
    # Set filter variables for the view
    @filter_room_id = params[:room_id]
    @filter_tenant_id = params[:tenant_id]
    @filter_status = params[:status]
    @filter_start_date_from = params[:start_date_from]
    @filter_start_date_to = params[:start_date_to]
    
    # Apply final ordering
    @room_assignments = @room_assignments.order(created_at: :desc)
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
    # Handle multiple tenant IDs
    room_id = params[:room_assignment][:room_id]
    tenant_ids = params[:tenant_ids] || []
    start_date = params[:room_assignment][:start_date]
    deposit_amount = params[:room_assignment][:deposit_amount]
    notes = params[:room_assignment][:notes]
    
    # If no tenants selected, return to form with error
    if tenant_ids.empty?
      @room_assignment = RoomAssignment.new(room_assignment_params)
      @room_assignment.errors.add(:base, t('room_assignments.no_tenants_selected'))
      
      @available_rooms = Room.where(status: ['available', 'occupied'])
      @available_tenants = Tenant.left_joins(:room_assignments)
                                .where('room_assignments.id IS NULL OR room_assignments.active = ?', false)
                                .distinct
      
      return render :new, status: :unprocessable_entity
    end
    
    # Create room assignments for each selected tenant
    created_assignments = []
    failed_assignments = []
    
    tenant_ids.each do |tenant_id|
      room_assignment = RoomAssignment.new(
        room_id: room_id,
        tenant_id: tenant_id,
        start_date: start_date,
        deposit_amount: deposit_amount,
        notes: notes,
        active: true
      )
      
      if room_assignment.save
        created_assignments << room_assignment
      else
        failed_assignments << { tenant_id: tenant_id, errors: room_assignment.errors.full_messages }
      end
    end
    
    # Set the room as occupied if at least one assignment was successful
    if created_assignments.any?
      Room.find(room_id).update(status: 'occupied')
      
      if failed_assignments.any?
        # Some assignments failed
        flash[:warning] = t('room_assignments.partial_success', count: created_assignments.size, total: tenant_ids.size)
      else
        # All assignments successful
        flash[:success] = t('room_assignments.multiple_create_success', count: created_assignments.size)
      end
      
      # Redirect to the room page if assignments were for a specific room
      redirect_to room_path(room_id)
    else
      # All assignments failed
      @room_assignment = RoomAssignment.new(room_assignment_params)
      @room_assignment.errors.add(:base, t('room_assignments.all_create_failed'))
      
      @available_rooms = Room.where(status: ['available', 'occupied'])
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
