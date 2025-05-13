class TenantsController < ApplicationController
  before_action :require_login
  before_action :set_tenant, only: [:show, :edit, :update, :destroy]

  def index
    @search_query = params[:search]
    @room_filter = params[:room_id]
    @building_filter = params[:building_id]
    
    # Start with base query
    query = Tenant.all
    
    # Apply search filter if present
    if @search_query.present?
      query = query.where("LOWER(name) LIKE ? OR 
                          LOWER(phone) LIKE ? OR 
                          LOWER(email) LIKE ? OR 
                          LOWER(id_number) LIKE ?", 
                          "%#{@search_query.downcase}%",
                          "%#{@search_query.downcase}%",
                          "%#{@search_query.downcase}%",
                          "%#{@search_query.downcase}%")
    end
    
    # Apply room filter if present
    if @room_filter.present?
      query = query.joins(:room_assignments)
                   .where(room_assignments: { room_id: @room_filter, active: true })
    end
    
    # Apply building filter if present
    if @building_filter.present?
      query = query.joins(room_assignments: :room)
                   .where(rooms: { building_id: @building_filter })
                   .where(room_assignments: { active: true })
    end
    
    @tenants = query.distinct
    
    respond_to do |format|
      format.html # renders the default index.html.erb template
      format.json do
        render json: @tenants.as_json(methods: :has_active_assignment)
      end
    end
  end

  def show
    @current_room = @tenant.current_room
    @room_assignments = @tenant.room_assignments.includes(:room).order(start_date: :desc)
    @vehicles = @tenant.vehicles
  end

  def new
    @tenant = Tenant.new
  end

  def create
    @tenant = Tenant.new(tenant_params)

    if @tenant.save
      flash[:success] = t('tenants.create_success')
      redirect_to @tenant
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tenant.update(tenant_params)
      flash[:success] = t('tenants.update_success')
      redirect_to @tenant
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @tenant.room_assignments.exists?
      flash[:danger] = "Cannot delete tenant with room assignments."
      redirect_to tenants_url
    else
      @tenant.destroy
      flash[:success] = t('tenants.delete_success')
      redirect_to tenants_url
    end
  end

  private

  def set_tenant
    @tenant = Tenant.find(params[:id])
  end

  def tenant_params
    params.require(:tenant).permit(:name, :phone, :email, :id_number, :move_in_date, :id_issue_date, :id_issue_place, :permanent_address)
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = "Please log in to access this page"
      redirect_to login_path
    end
  end
end
