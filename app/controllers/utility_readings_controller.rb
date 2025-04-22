class UtilityReadingsController < ApplicationController
  before_action :require_login
  before_action :set_utility_reading, only: [:show, :edit, :update, :destroy]

  def index
    @utility_readings = UtilityReading.includes(:room).order(reading_date: :desc)
  end

  def show
    @previous_reading = @utility_reading.previous_reading
    @electricity_usage = @utility_reading.electricity_usage
    @water_usage = @utility_reading.water_usage
    @electricity_cost = @utility_reading.electricity_cost
    @water_cost = @utility_reading.water_cost
  end

  def new
    @utility_reading = UtilityReading.new
    @rooms = Room.all
  end

  def create
    @utility_reading = UtilityReading.new(utility_reading_params)

    if @utility_reading.save
      flash[:success] = t('utility_readings.create_success')
      redirect_to @utility_reading
    else
      @rooms = Room.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @rooms = Room.all
  end

  def update
    if @utility_reading.update(utility_reading_params)
      flash[:success] = t('utility_readings.update_success')
      redirect_to @utility_reading
    else
      @rooms = Room.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @utility_reading.destroy
    flash[:success] = t('utility_readings.delete_success')
    redirect_to utility_readings_url
  end

  private

  def set_utility_reading
    @utility_reading = UtilityReading.find(params[:id])
  end

  def utility_reading_params
    params.require(:utility_reading).permit(:room_id, :reading_date, :electricity_reading, 
                                           :water_reading, :electricity_unit_price, :water_unit_price)
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t('auth.login_required')
      redirect_to login_path
    end
  end
end
