class UtilityPricesController < ApplicationController
  before_action :require_login
  before_action :set_utility_price, only: [:show, :edit, :update, :destroy]

  def index
    @utility_prices = UtilityPrice.order(effective_date: :desc)
    @current_price = UtilityPrice.current
  end

  def show
  end

  def new
    @utility_price = UtilityPrice.new
    
    # Pre-populate with values from the most recent price configuration
    if UtilityPrice.exists?
      latest = UtilityPrice.current
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
      flash[:success] = t('utility_prices.create_success')
      redirect_to utility_prices_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @utility_price.update(utility_price_params)
      flash[:success] = t('utility_prices.update_success')
      redirect_to utility_prices_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @utility_price == UtilityPrice.current && UtilityPrice.count > 1
      flash[:danger] = t('utility_prices.cannot_delete_current')
      redirect_to utility_prices_path
    else
      @utility_price.destroy
      flash[:success] = t('utility_prices.delete_success')
      redirect_to utility_prices_path
    end
  end

  private

  def set_utility_price
    @utility_price = UtilityPrice.find(params[:id])
  end

  def utility_price_params
    params.require(:utility_price).permit(:electricity_unit_price, :water_unit_price, 
                                        :service_charge, :effective_date, :notes)
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t('auth.login_required')
      redirect_to login_path
    end
  end
end
