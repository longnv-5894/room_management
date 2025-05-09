class UtilityPricesController < ApplicationController
  before_action :require_login
  before_action :set_utility_price, only: [ :show, :edit, :update, :destroy ]
  before_action :load_buildings, only: [ :new, :create, :edit, :update, :index ]

  def index
    @utility_prices = UtilityPrice.order(effective_date: :desc)

    # Filter by building if provided
    if params[:building_id].present?
      building_id = params[:building_id].to_i
      @building = Building.find_by(id: building_id)

      if @building
        # Get prices specific to this building or global prices
        @utility_prices = @utility_prices.where("building_id = ? OR building_id IS NULL", building_id)
        @current_price = UtilityPrice.current(building_id)
      else
        @current_price = UtilityPrice.current
      end
    else
      @current_price = UtilityPrice.current
    end

    @buildings = Building.order(:name)
  end

  def show
  end

  def new
    @utility_price = UtilityPrice.new
    @utility_price.building_id = params[:building_id] if params[:building_id].present?

    # Pre-populate with values from the most recent price configuration
    if UtilityPrice.exists?
      latest = if params[:building_id].present?
                UtilityPrice.current(params[:building_id])
      else
                UtilityPrice.current
      end
      @utility_price.electricity_unit_price = latest.electricity_unit_price
      @utility_price.water_unit_price = latest.water_unit_price
      @utility_price.service_charge = latest.service_charge
    else
      # Default values if no prior configuration exists
      @utility_price.electricity_unit_price = 3500
      @utility_price.water_unit_price = 15000
      @utility_price.service_charge = 200000
    end

    @utility_price.effective_date = Date.today
  end

  def create
    @utility_price = UtilityPrice.new(utility_price_params)

    if @utility_price.save
      flash[:success] = t("utility_prices.create_success")
      redirect_to utility_prices_path(building_id: @utility_price.building_id)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @utility_price.update(utility_price_params)
      flash[:success] = t("utility_prices.update_success")
      redirect_to utility_prices_path(building_id: @utility_price.building_id)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    building_id = @utility_price.building_id
    if @utility_price == UtilityPrice.current(building_id) && UtilityPrice.where(building_id: building_id).count > 1
      flash[:danger] = t("utility_prices.cannot_delete_current")
      redirect_to utility_prices_path(building_id: building_id)
    else
      @utility_price.destroy
      flash[:success] = t("utility_prices.delete_success")
      redirect_to utility_prices_path(building_id: building_id)
    end
  end

  private

  def set_utility_price
    @utility_price = UtilityPrice.find(params[:id])
  end

  def utility_price_params
    params.require(:utility_price).permit(:electricity_unit_price, :water_unit_price,
                                        :service_charge, :effective_date, :notes, :building_id)
  end

  def load_buildings
    @buildings = Building.order(:name)
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t("auth.login_required")
      redirect_to login_path
    end
  end
end
