class UtilityReadingsController < ApplicationController
  before_action :require_login
  before_action :set_utility_reading, only: [ :show, :edit, :update, :destroy ]

  def index
    # Start with base query
    query = UtilityReading.includes(room: :building)

    # Apply building filter
    if params[:building_id].present?
      query = query.joins(:room).where(rooms: { building_id: params[:building_id] })
    end

    # Apply room filter (takes precedence over building filter)
    if params[:room_id].present?
      query = query.where(room_id: params[:room_id])
    end

    # Apply date range filters
    if params[:start_date].present?
      query = query.where("reading_date >= ?", params[:start_date])
    end

    if params[:end_date].present?
      query = query.where("reading_date <= ?", params[:end_date])
    end

    # Final ordering
    @utility_readings = query.order(reading_date: :desc)

    # Return correct format
    service_charge = 0
    if params[:room_id].present?
      service_charge = UtilityPrice.current.service_charge * RoomAssignment.where(room_id: params[:room_id], active: true).count
    end

    respond_to do |format|
      format.html # renders the default index.html.erb template
      format.json do
        if params[:room_id].present?
          latest_readings = @utility_readings.limit(2).map do |reading|
            {
              id: reading.id,
              reading_date: reading.reading_date,
              room_id: reading.room_id,
              room_number: reading.room.number,
              utility_type: reading.previous_reading ? "electricity" : "water",
              previous_reading: reading.previous_reading&.electricity_reading || 0,
              current_reading: reading.electricity_reading,
              rate: reading.electricity_unit_price,
              water_previous_reading: reading.previous_reading&.water_reading || 0,
              water_current_reading: reading.water_reading,
              water_rate: reading.water_unit_price,
              service_charge: reading.service_charge
            }
          end

          # If we have a reading, organize the data for the form
          if latest_readings.present?
            latest = latest_readings.first
            render json: [
              {
                id: latest[:id],
                utility_type: "electricity",
                reading_date: latest[:reading_date],
                previous_reading: latest[:previous_reading],
                current_reading: latest[:current_reading],
                rate: latest[:rate],
                service_charge: service_charge
              },
              {
                id: latest[:id],
                utility_type: "water",
                reading_date: latest[:reading_date],
                previous_reading: latest[:water_previous_reading],
                current_reading: latest[:water_current_reading],
                rate: latest[:water_rate]
              }
            ]
          else
            render json: []
          end
        else
          render json: @utility_readings
        end
      end
    end
  end

  def show
    @previous_reading = @utility_reading.previous_reading
    @electricity_usage = @utility_reading.electricity_usage
    @water_usage = @utility_reading.water_usage
    @electricity_cost = @utility_reading.electricity_cost
    @water_cost = @utility_reading.water_cost
    @service_charge_cost = @utility_reading.service_charge_cost
    @total_cost = @utility_reading.total_cost

    # Find the current tenant of the room for the sidebar
    active_assignment = @utility_reading.room.room_assignments.find_by(active: true)
    @room_tenant = active_assignment&.tenant
  end

  def new
    @utility_reading = UtilityReading.new
    @rooms = Room.all
  end

  def create
    @utility_reading = UtilityReading.new(utility_reading_params)

    if @utility_reading.save
      flash[:success] = t("utility_readings.create_success")
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
      flash[:success] = t("utility_readings.update_success")
      redirect_to @utility_reading
    else
      @rooms = Room.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @utility_reading.destroy
    flash[:success] = t("utility_readings.delete_success")
    redirect_to utility_readings_url
  end

  private

  def set_utility_reading
    @utility_reading = UtilityReading.find(params[:id])
  end

  def utility_reading_params
    params.require(:utility_reading).permit(:room_id, :reading_date, :electricity_reading,
                                           :water_reading)
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t("auth.login_required")
      redirect_to login_path
    end
  end
end
