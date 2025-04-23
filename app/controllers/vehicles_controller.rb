class VehiclesController < ApplicationController
  before_action :set_vehicle, only: [:show, :edit, :update, :destroy]
  before_action :set_tenant, only: [:index, :new, :create]
  
  def index
    @search_query = params[:search]
    @room_filter = params[:room_id]
    base_vehicles = @tenant ? @tenant.vehicles : Vehicle.includes(:tenant)
    
    if @search_query.present? || @room_filter.present?
      # Start with base query
      query = base_vehicles.joins(:tenant)
      
      # Apply search query if present (case insensitive)
      if @search_query.present?
        query = query.where("LOWER(license_plate) LIKE ? OR 
                         LOWER(vehicle_type) LIKE ? OR 
                         LOWER(brand) LIKE ? OR 
                         LOWER(model) LIKE ? OR 
                         LOWER(color) LIKE ? OR
                         LOWER(tenants.name) LIKE ?", 
                         "%#{@search_query.downcase}%", 
                         "%#{@search_query.downcase}%", 
                         "%#{@search_query.downcase}%", 
                         "%#{@search_query.downcase}%", 
                         "%#{@search_query.downcase}%",
                         "%#{@search_query.downcase}%")
      end
      
      # Apply room filter if present
      if @room_filter.present?
        query = query.joins(tenant: :room_assignments)
                    .where(room_assignments: { room_id: @room_filter, active: true })
      end
      
      @vehicles = query.distinct
    else
      @vehicles = base_vehicles.all
    end
    
    # Get rooms for the filter dropdown
    @rooms = Room.order(:number)
  end
  
  def show
    @tenant = @vehicle.tenant
  end
  
  def new
    @vehicle = Vehicle.new(tenant_id: params[:tenant_id])
    @tenants = Tenant.all if @tenant.nil?
  end
  
  def create
    @vehicle = Vehicle.new(vehicle_params)
    
    if @vehicle.save
      if params[:tenant_id]
        redirect_to tenant_vehicles_path(@vehicle.tenant), notice: t('vehicles.create_success')
      else
        redirect_to vehicles_path, notice: t('vehicles.create_success')
      end
    else
      @tenants = Tenant.all if @tenant.nil?
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @tenant = @vehicle.tenant
    @tenants = Tenant.all
  end
  
  def update
    if @vehicle.update(vehicle_params)
      if params[:tenant_id]
        redirect_to tenant_vehicles_path(@vehicle.tenant), notice: t('vehicles.update_success')
      else
        redirect_to vehicles_path, notice: t('vehicles.update_success')
      end
    else
      @tenants = Tenant.all
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    tenant = @vehicle.tenant
    @vehicle.destroy
    
    if params[:tenant_id]
      redirect_to tenant_vehicles_path(tenant), notice: t('vehicles.delete_success')
    else
      redirect_to vehicles_path, notice: t('vehicles.delete_success')
    end
  end
  
  private
  
  def set_vehicle
    @vehicle = Vehicle.find(params[:id])
  end
  
  def set_tenant
    @tenant = Tenant.find(params[:tenant_id]) if params[:tenant_id]
  end
  
  def vehicle_params
    params.require(:vehicle).permit(:license_plate, :vehicle_type, :brand, :model, :color, :tenant_id, :notes)
  end
end
