class RoomAssignmentsController < ApplicationController
  before_action :require_login
  before_action :set_room_assignment, only: [ :show, :edit, :update, :destroy, :end, :make_representative, :activate ]

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
      @room_assignments = @room_assignments.where(active: params[:status] == "active")
    end

    # Apply date range filter for start_date
    if params[:start_date_from].present?
      @room_assignments = @room_assignments.where("start_date >= ?", params[:start_date_from])
    end

    if params[:start_date_to].present?
      @room_assignments = @room_assignments.where("start_date <= ?", params[:start_date_to])
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
          room_fee_frequency: @room_assignment.effective_room_fee_frequency,
          utility_fee_frequency: @room_assignment.effective_utility_fee_frequency,
          is_representative_tenant: @room_assignment.is_representative_tenant?,
          room: {
            id: @room_assignment.room.id,
            number: @room_assignment.room.number,
            # Lấy giá phòng trực tiếp từ room_assignment thay vì từ room
            monthly_rent: @room_assignment.monthly_rent,
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
    @available_rooms = Room.where(status: [ "available", "occupied" ])

    # Only show tenants who aren't already assigned to any room
    @available_tenants = Tenant.left_joins(:room_assignments)
                              .where("room_assignments.id IS NULL OR room_assignments.active = ?", false)
                              .distinct

    # Set default payment frequencies
    @room_assignment.room_fee_frequency = 1
    @room_assignment.utility_fee_frequency = 1

    # Common payment frequency options for dropdowns
    @payment_frequency_options = [
      [ 1, "#{t('room_assignments.monthly')} (1 #{t('room_assignments.frequency_unit')})" ],
      [ 2, "#{t('room_assignments.every_n_months', count: 2)} (2 #{t('room_assignments.frequency_unit')})" ],
      [ 3, "#{t('room_assignments.every_n_months', count: 3)} (3 #{t('room_assignments.frequency_unit')})" ],
      [ 6, "#{t('room_assignments.every_n_months', count: 6)} (6 #{t('room_assignments.frequency_unit')})" ],
      [ 12, "#{t('room_assignments.every_n_months', count: 12)} (12 #{t('room_assignments.frequency_unit')})" ]
    ]
  end

  def create
    # Handle multiple tenant IDs
    room_id = params[:room_assignment][:room_id]
    tenant_ids = params[:tenant_ids] || []
    start_date = params[:room_assignment][:start_date]
    deposit_amount = params[:room_assignment][:deposit_amount]
    monthly_rent = params[:room_assignment][:monthly_rent]
    notes = params[:room_assignment][:notes]
    room_fee_frequency = params[:room_assignment][:room_fee_frequency]
    utility_fee_frequency = params[:room_assignment][:utility_fee_frequency]

    # If no tenants selected, return to form with error
    if tenant_ids.empty?
      @room_assignment = RoomAssignment.new(room_assignment_params)
      @room_assignment.errors.add(:base, t("room_assignments.no_tenants_selected"))

      @available_rooms = Room.where(status: [ "available", "occupied" ])
      @available_tenants = Tenant.left_joins(:room_assignments)
                                .where("room_assignments.id IS NULL OR room_assignments.active = ?", false)
                                .distinct
      @payment_frequency_options = [
        [ 1, "#{t('room_assignments.monthly')} (1 #{t('room_assignments.frequency_unit')})" ],
        [ 2, "#{t('room_assignments.every_n_months', count: 2)} (2 #{t('room_assignments.frequency_unit')})" ],
        [ 3, "#{t('room_assignments.every_n_months', count: 3)} (3 #{t('room_assignments.frequency_unit')})" ],
        [ 6, "#{t('room_assignments.every_n_months', count: 6)} (6 #{t('room_assignments.frequency_unit')})" ],
        [ 12, "#{t('room_assignments.every_n_months', count: 12)} (12 #{t('room_assignments.frequency_unit')})" ]
      ]

      return render :new, status: :unprocessable_entity
    end

    # Create room assignments for each selected tenant
    created_assignments = []
    failed_assignments = []

    # Check if this is the first tenant for the room
    room = Room.find(room_id)
    is_first_tenant = !room.room_assignments.where(active: true).exists?

    # Ensure frequencies are integers
    room_fee_frequency = room_fee_frequency.to_i if room_fee_frequency.present?
    utility_fee_frequency = utility_fee_frequency.to_i if utility_fee_frequency.present?

    tenant_ids.each_with_index do |tenant_id, index|
      room_assignment = RoomAssignment.new(
        room_id: room_id,
        tenant_id: tenant_id,
        start_date: start_date,
        # Only set deposit amount for the first tenant (who will be representative)
        deposit_amount: (index == 0 && is_first_tenant) ? deposit_amount : nil,
        # Ensure all tenants in same room have the same monthly rent
        monthly_rent: monthly_rent,
        notes: notes,
        active: true,
        # First tenant becomes the representative
        is_representative_tenant: (index == 0 && is_first_tenant),
        # Only set payment frequencies for the representative tenant
        room_fee_frequency: (index == 0 && is_first_tenant) ? room_fee_frequency : 1.to_i,
        utility_fee_frequency: (index == 0 && is_first_tenant) ? utility_fee_frequency : 1.to_i
      )

      if room_assignment.save
        created_assignments << room_assignment
      else
        failed_assignments << { tenant_id: tenant_id, errors: room_assignment.errors.full_messages }
      end
    end

    # Set the room as occupied if at least one assignment was successful
    if created_assignments.any?
      Room.find(room_id).update(status: "occupied")

      if failed_assignments.any?
        # Some assignments failed
        flash[:warning] = t("room_assignments.partial_success", count: created_assignments.size, total: tenant_ids.size)
      else
        # All assignments successful
        flash[:success] = t("room_assignments.multiple_create_success", count: created_assignments.size)
      end

      # Redirect to the room page if assignments were for a specific room
      redirect_to room_path(room_id)
    else
      # All assignments failed
      @room_assignment = RoomAssignment.new(room_assignment_params)
      @room_assignment.errors.add(:base, t("room_assignments.all_create_failed"))

      @available_rooms = Room.where(status: [ "available", "occupied" ])
      @available_tenants = Tenant.left_joins(:room_assignments)
                                .where("room_assignments.id IS NULL OR room_assignments.active = ?", false)
                                .distinct
      @payment_frequency_options = [
        [ 1, "#{t('room_assignments.monthly')} (1 #{t('room_assignments.frequency_unit')})" ],
        [ 2, "#{t('room_assignments.every_n_months', count: 2)} (2 #{t('room_assignments.frequency_unit')})" ],
        [ 3, "#{t('room_assignments.every_n_months', count: 3)} (3 #{t('room_assignments.frequency_unit')})" ],
        [ 6, "#{t('room_assignments.every_n_months', count: 6)} (6 #{t('room_assignments.frequency_unit')})" ],
        [ 12, "#{t('room_assignments.every_n_months', count: 12)} (12 #{t('room_assignments.frequency_unit')})" ]
      ]

      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_rooms = Room.where(status: "available")
    @available_rooms = @available_rooms.or(Room.where(id: @room_assignment.room_id))
    @available_tenants = Tenant.all
    @payment_frequency_options = [
      [ 1.to_i, "#{t('room_assignments.monthly')} (1 #{t('room_assignments.frequency_unit')})" ],
      [ 2.to_i, "#{t('room_assignments.every_n_months', count: 2)} (2 #{t('room_assignments.frequency_unit')})" ],
      [ 3.to_i, "#{t('room_assignments.every_n_months', count: 3)} (3 #{t('room_assignments.frequency_unit')})" ],
      [ 6.to_i, "#{t('room_assignments.every_n_months', count: 6)} (6 #{t('room_assignments.frequency_unit')})" ],
      [ 12.to_i, "#{t('room_assignments.every_n_months', count: 12)} (12 #{t('room_assignments.frequency_unit')})" ]
    ]
  end

  def update
    # Handle case where frequency values might come in as strings
    frequency_params = params[:room_assignment]

    # Extract frequency values from the form and convert to integers if they're strings
    if frequency_params[:room_fee_frequency].present?
      # If it's a string containing numbers, extract just the first number
      if frequency_params[:room_fee_frequency].is_a?(String) && frequency_params[:room_fee_frequency].match(/\d+/)
        frequency_params[:room_fee_frequency] = frequency_params[:room_fee_frequency].match(/\d+/)[0].to_i
      else
        frequency_params[:room_fee_frequency] = frequency_params[:room_fee_frequency].to_i
      end
    end

    if frequency_params[:utility_fee_frequency].present?
      # If it's a string containing numbers, extract just the first number
      if frequency_params[:utility_fee_frequency].is_a?(String) && frequency_params[:utility_fee_frequency].match(/\d+/)
        frequency_params[:utility_fee_frequency] = frequency_params[:utility_fee_frequency].match(/\d+/)[0].to_i
      else
        frequency_params[:utility_fee_frequency] = frequency_params[:utility_fee_frequency].to_i
      end
    end

    if @room_assignment.update(room_assignment_params)
      flash[:success] = t("room_assignments.update_success")
      redirect_to @room_assignment
    else
      @available_rooms = Room.where(status: "available")
      @available_rooms = @available_rooms.or(Room.where(id: @room_assignment.room_id))
      @available_tenants = Tenant.all
      @payment_frequency_options = [
        [ 1.to_i, "#{t('room_assignments.monthly')} (1 #{t('room_assignments.frequency_unit')})" ],
        [ 2.to_i, "#{t('room_assignments.every_n_months', count: 2)} (2 #{t('room_assignments.frequency_unit')})" ],
        [ 3.to_i, "#{t('room_assignments.every_n_months', count: 3)} (3 #{t('room_assignments.frequency_unit')})" ],
        [ 6.to_i, "#{t('room_assignments.every_n_months', count: 6)} (6 #{t('room_assignments.frequency_unit')})" ],
        [ 12.to_i, "#{t('room_assignments.every_n_months', count: 12)} (12 #{t('room_assignments.frequency_unit')})" ]
      ]
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    room = @room_assignment.room
    tenant_name = @room_assignment.tenant.name

    if @room_assignment.bills.exists?
      flash[:danger] = t("room_assignments.cannot_delete_with_bills")
      redirect_to room_assignments_url
      return
    end

    if @room_assignment.destroy
      # Check if this was the representative tenant
      if @room_assignment.is_representative_tenant?
        # Find another active tenant for this room and make them the representative
        other_active_tenant = room.room_assignments.where(active: true).first
        if other_active_tenant
          other_active_tenant.update(is_representative_tenant: true)
        end
      end

      # Update room status to available if no active assignments remain
      if room.room_assignments.where(active: true).empty?
        room.update(status: "available")
      end

      flash[:success] = t("room_assignments.delete_success", tenant: tenant_name, default: "Room assignment for #{tenant_name} was successfully deleted")
    else
      flash[:danger] = t("room_assignments.delete_error", default: "Failed to delete room assignment")
    end

    redirect_to room_assignments_url
  end

  def end
    room = @room_assignment.room

    if @room_assignment.update(active: false, end_date: Date.today)
      # If this was the representative tenant, assign a new one
      if @room_assignment.is_representative_tenant?
        other_active_tenant = room.room_assignments.where(active: true).first
        if other_active_tenant
          other_active_tenant.update(is_representative_tenant: true)
        end
      end

      # Only update room status to available if no active assignments remain
      if room.room_assignments.where(active: true).empty?
        room.update(status: "available")
      end

      flash[:success] = t("room_assignments.end_success")
      redirect_to room_path(room)
    else
      flash[:danger] = t("room_assignments.end_error")
      redirect_to room_path(room)
    end
  end

  def make_representative
    if @room_assignment.active?
      @room_assignment.make_representative!
      flash[:success] = t("room_assignments.representative_set_success", name: @room_assignment.tenant.name)
    else
      flash[:danger] = t("room_assignments.inactive_tenant_error")
    end
    redirect_to room_path(@room_assignment.room)
  end

  def activate
    room = @room_assignment.room

    if @room_assignment.update(active: true, end_date: nil)
      # Update room status to occupied
      room.update(status: "occupied") unless room.status == "occupied"

      # If there's no representative for the room, make this tenant the representative
      unless room.room_assignments.where(active: true, is_representative_tenant: true).exists?
        @room_assignment.make_representative!
      end

      flash[:success] = t("room_assignments.activate_success")
      redirect_to room_path(room)
    else
      flash[:danger] = t("room_assignments.activate_error")
      redirect_to room_path(room)
    end
  end

  private

  def set_room_assignment
    @room_assignment = RoomAssignment.find(params[:id])
  end

  def room_assignment_params
    parameters = params.require(:room_assignment).permit(:room_id, :tenant_id, :start_date,
                                           :end_date, :deposit_amount, :active, :is_representative_tenant,
                                           :room_fee_frequency, :utility_fee_frequency, :notes, :monthly_rent)

    # Ensure frequency fields are integers
    parameters[:room_fee_frequency] = parameters[:room_fee_frequency].to_i if parameters[:room_fee_frequency].present?
    parameters[:utility_fee_frequency] = parameters[:utility_fee_frequency].to_i if parameters[:utility_fee_frequency].present?

    parameters
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t("auth.login_required")
      redirect_to login_path
    end
  end
end
