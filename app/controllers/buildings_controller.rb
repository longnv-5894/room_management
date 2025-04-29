class BuildingsController < ApplicationController
  before_action :require_login
  before_action :set_building, only: [:show, :edit, :update, :destroy]
  before_action :set_location_collections, only: [:new, :edit, :create, :update]

  def index
    @buildings = current_user.buildings.order(created_at: :desc)
  end

  def show
    @rooms = @building.rooms.order(:number)
    @occupied_rooms = @rooms.where(status: 'occupied')
    @operating_expenses = @building.operating_expenses.order(expense_date: :desc).limit(5)
    
    # Calculate summary metrics
    @total_rooms = @rooms.count
    @occupancy_rate = @building.occupancy_rate
    @total_tenants = @building.total_tenants
    
    # Calculate monthly revenue and expenses
    current_month = Date.today.month
    current_year = Date.today.year
    @monthly_revenue = @building.actual_monthly_revenue
    @monthly_expenses = OperatingExpense.total_for_month_and_building(current_year, current_month, @building.id)
  end

  def new
    @building = Building.new
  end

  def create
    @building = current_user.buildings.build(building_params)
    
    if @building.save
      flash[:success] = t('buildings.created')
      redirect_to @building
    else
      flash.now[:danger] = t('buildings.create_error')
      render 'new', status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @building.update(building_params)
      flash[:success] = t('buildings.updated')
      redirect_to @building
    else
      flash.now[:danger] = t('buildings.update_error')
      render 'edit', status: :unprocessable_entity
    end
  end

  def destroy
    if @building.rooms.exists?
      flash[:danger] = t('buildings.cannot_delete')
      redirect_to buildings_path
    else
      @building.destroy
      flash[:success] = t('buildings.deleted')
      redirect_to buildings_path
    end
  end

  private

  def set_building
    @building = current_user.buildings.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = t('buildings.not_found')
    redirect_to buildings_path
  end

  def set_location_collections
    @countries = Country.order(:name)
    # If country is selected, filter cities by country
    if params[:country_id].present?
      @cities = City.where(country_id: params[:country_id]).order(:name)
    elsif @building&.country_id.present?
      @cities = City.where(country_id: @building.country_id).order(:name)
    else
      @cities = City.none
    end
    
    # If city is selected, filter districts by city
    if params[:city_id].present?
      @districts = District.where(city_id: params[:city_id]).order(:name)
    elsif @building&.city_id.present?
      @districts = District.where(city_id: @building.city_id).order(:name)
    else
      @districts = District.none
    end
    
    # If district is selected, filter wards by district
    if params[:district_id].present?
      @wards = Ward.where(district_id: params[:district_id]).order(:name)
    elsif @building&.district_id.present?
      @wards = Ward.where(district_id: @building.district_id).order(:name)
    else
      @wards = Ward.none
    end
  end

  def building_params
    params.require(:building).permit(:name, :address, :description, :num_floors, 
                                    :year_built, :total_area, :status,
                                    :country_id, :city_id, :district_id, :ward_id, :street_address)
  end

  def require_login
    unless current_user
      flash[:danger] = t('auth.login_required')
      redirect_to login_path
    end
  end
end
