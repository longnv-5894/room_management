class RevenuesController < ApplicationController
  before_action :require_login

  def index
    # Get year and month from params or use current date
    @year = params[:year].present? ? params[:year].to_i : Date.today.year
    @month = params[:month].present? ? params[:month].to_i : Date.today.month
    @date = Date.new(@year, @month, 1)

    # Set date range for current month
    @start_date = @date.beginning_of_month
    @end_date = @date.end_of_month

    # Calculate monthly statistics
    calculate_monthly_statistics

    # Get yearly data for charts
    prepare_yearly_data

    # Get revenues and expenses details
    @recent_revenues = Bill.where(billing_date: @start_date..@end_date)
                          .where(status: "paid")
                          .order(billing_date: :desc)
                          .limit(10)

    @recent_expenses = OperatingExpense.where(expense_date: @start_date..@end_date)
                                     .order(expense_date: :desc)
                                     .limit(10)

    # Calculate profits by building
    calculate_profits_by_building
  end

  private

  def calculate_monthly_statistics
    # Calculate total revenue - only from paid bills
    @monthly_revenue = Bill.where(billing_date: @start_date..@end_date)
                           .where(status: "paid")
                           .sum(:total_amount)

    # Calculate total expenses
    @monthly_expenses = OperatingExpense.where(expense_date: @start_date..@end_date).sum(:amount)

    # Calculate profit
    @monthly_profit = @monthly_revenue - @monthly_expenses

    # Calculate profit margin
    @profit_margin = @monthly_revenue.zero? ? 0 : (@monthly_profit / @monthly_revenue * 100).round(2)
  end

  def prepare_yearly_data
    current_year = Date.today.year
    @yearly_data = {
      months: [],
      revenue: [],
      expenses: [],
      profit: []
    }

    12.times do |i|
      month = Date.new(current_year, i + 1, 1)
      month_end = month.end_of_month

      # Skip future months
      next if month > Date.today

      month_revenue = Bill.where(billing_date: month.beginning_of_month..month_end)
                         .where(status: "paid")
                         .sum(:total_amount)
      month_expenses = OperatingExpense.where(expense_date: month.beginning_of_month..month_end).sum(:amount)
      month_profit = month_revenue - month_expenses

      @yearly_data[:months] << I18n.l(month, format: "%b")
      @yearly_data[:revenue] << month_revenue
      @yearly_data[:expenses] << month_expenses
      @yearly_data[:profit] << month_profit
    end
  end

  def calculate_profits_by_building
    @profits_by_building = []

    # Get all buildings
    buildings = Building.all

    buildings.each do |building|
      # Get rooms for this building
      rooms = building.rooms

      # Calculate revenue for this building - only from paid bills
      revenue = Bill.joins(room_assignment: :room)
                   .where(rooms: { building_id: building.id })
                   .where(billing_date: @start_date..@end_date)
                   .where(status: "paid")
                   .sum(:total_amount)

      # Calculate expenses for this building
      expenses = OperatingExpense.where(building_id: building.id)
                               .where(expense_date: @start_date..@end_date)
                               .sum(:amount)

      # Calculate profit
      profit = revenue - expenses

      # Calculate profit margin
      profit_margin = revenue.zero? ? 0 : (profit / revenue * 100).round(2)

      # Calculate occupancy rate
      total_rooms = rooms.count
      occupied_rooms = rooms.joins(:room_assignments)
                           .where("room_assignments.start_date <= ?", @end_date)
                           .where("room_assignments.end_date IS NULL OR room_assignments.end_date >= ?", @start_date)
                           .distinct.count

      occupancy_rate = total_rooms.zero? ? 0 : (occupied_rooms.to_f / total_rooms * 100).round(2)

      @profits_by_building << {
        building: building,
        revenue: revenue,
        expenses: expenses,
        profit: profit,
        profit_margin: profit_margin,
        occupancy_rate: occupancy_rate
      }
    end

    # Sort by profit (highest first)
    @profits_by_building.sort_by! { |data| -data[:profit] }
  end
end
