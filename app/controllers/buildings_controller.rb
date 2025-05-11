class BuildingsController < ApplicationController
  before_action :require_login
  before_action :set_building, only: [ :show, :edit, :update, :destroy, :import_form, :import_excel ]
  before_action :set_location_collections, only: [ :new, :edit, :create, :update ]

  def index
    @buildings = current_user.buildings.order(created_at: :desc)
  end

  def show
    @rooms = @building.rooms.order(:number)
    @occupied_rooms = @rooms.where(status: "occupied")
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

    # Get monthly financial data for report (last 6 months by default)
    months_to_show = params[:months].present? ? params[:months].to_i : 6
    @monthly_financial_data = get_monthly_financial_data(@building, months_to_show)
    @total_financial_data = calculate_total_financial_data(@monthly_financial_data)
  end

  # Get monthly financial data for a building
  def get_monthly_financial_data(building, months = 6)
    result = []

    # Start from current month and go back for the specified number of months
    current_date = Date.today.beginning_of_month
    months.times do |i|
      month_date = current_date - i.months
      month_end = month_date.end_of_month

      # Calculate revenue for this building and month
      revenue = Bill.joins(room_assignment: :room)
                    .where(rooms: { building_id: building.id })
                    .where(billing_date: month_date..month_end)
                    .sum(:total_amount)

      # Calculate expenses for this building and month
      expenses = OperatingExpense.where(building_id: building.id)
                                .where(expense_date: month_date..month_end)
                                .sum(:amount)

      # Calculate profit
      profit = revenue - expenses

      # Calculate profit margin
      margin = revenue > 0 ? ((profit.to_f / revenue) * 100).round(1) : 0

      result << {
        month: month_date,
        revenue: revenue,
        expenses: expenses,
        profit: profit,
        margin: margin
      }
    end

    result
  end

  # Calculate totals for financial data
  def calculate_total_financial_data(monthly_data)
    total_revenue = monthly_data.sum { |data| data[:revenue] }
    total_expenses = monthly_data.sum { |data| data[:expenses] }
    total_profit = total_revenue - total_expenses
    total_margin = total_revenue > 0 ? ((total_profit.to_f / total_revenue) * 100).round(1) : 0

    {
      revenue: total_revenue,
      expenses: total_expenses,
      profit: total_profit,
      margin: total_margin
    }
  end

  # Excel Import actions
  def import_form
    render "import"
  end

  def import_excel
    if params[:file].nil?
      flash[:danger] = t("buildings.import.no_file")
      redirect_to import_form_building_path(@building)
      return
    end

    begin
      # Save the uploaded file temporarily
      file_path = Rails.root.join("tmp", "import_#{SecureRandom.uuid}_#{params[:file].original_filename}")
      File.open(file_path, "wb") do |file|
        file.write(params[:file].read)
      end

      # Get month and year from filename for better error messages
      filename = params[:file].original_filename
      month = nil
      year = nil
      if filename =~ /tháng\s*(\d+)[\/\-](\d{4})/i
        month = $1.to_i
        year = $2.to_i
      end

      # Process the file
      service = ExcelImportService.new(file_path.to_s, @building)

      if service.import
        flash[:success] = t("buildings.import.success",
                          rooms: service.imported_count[:rooms],
                          tenants: service.imported_count[:tenants],
                          readings: service.imported_count[:utility_readings],
                          bills: service.imported_count[:bills],
                          expenses: service.imported_count[:expenses] || 0,
                          utility_prices: service.imported_count[:utility_prices] || 0,
                          month: service.billing_month,
                          year: service.billing_year)
        redirect_to @building
      else
        error_message = service.errors.join(", ")
        flash[:danger] = t("buildings.import.failed", errors: error_message)
        redirect_to import_form_building_path(@building)
      end

    rescue => e
      error_msg = "#{e.class.name}: #{e.message}"
      if month && year
        error_msg += " (Tháng #{month}/#{year})"
      end
      flash[:danger] = t("buildings.import.error", message: error_msg)
      redirect_to import_form_building_path(@building)
    ensure
      # Clean up temporary file
      File.delete(file_path) if file_path && File.exist?(file_path)
    end
  end

  def new
    @building = Building.new
  end

  def create
    @building = Building.new(building_params)
    @building.user = current_user

    if @building.save
      flash[:success] = t("buildings.created")
      redirect_to buildings_path
    else
      flash.now[:danger] = t("buildings.create_error")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @building.update(building_params)
      flash[:success] = t("buildings.updated")
      redirect_to building_path(@building)
    else
      flash.now[:danger] = t("buildings.update_error")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @building.destroy
    flash[:success] = t("buildings.deleted")
    redirect_to buildings_path
  end

  private

  def set_building
    @building = current_user.buildings.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = t("buildings.not_found")
    redirect_to buildings_path
  end

  def building_params
    params.require(:building).permit(:name, :address, :description, :num_floors,
                                    :year_built, :total_area, :status,
                                    :country_id, :city_id, :district_id, :ward_id, :street_address)
  end

  def require_login
    unless current_user
      flash[:danger] = t("auth.login_required")
      redirect_to login_path
    end
  end

  def set_location_collections
    @countries = Country.all.order(:name)
    @cities = []
    @districts = []
    @wards = []

    if @building&.country_id.present?
      @cities = City.where(country_id: @building.country_id).order(:name)
    end

    if @building&.city_id.present?
      @districts = District.where(city_id: @building.city_id).order(:name)
    end

    if @building&.district_id.present?
      @wards = Ward.where(district_id: @building.district_id).order(:name)
    end
  end
end
