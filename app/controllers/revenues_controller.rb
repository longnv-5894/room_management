class RevenuesController < ApplicationController
  def index
    # Set the year and month for the revenue display
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    @date = Date.new(@year, @month, 1)
    
    # Calculate this month's revenue (total of all bills for the month)
    @monthly_revenue = calculate_monthly_revenue(@year, @month)
    
    # Calculate this month's operating expenses
    @monthly_expenses = calculate_monthly_expenses(@year, @month)
    
    # Calculate profit (revenue - expenses)
    @monthly_profit = @monthly_revenue - @monthly_expenses
    
    # Get data for yearly chart
    @yearly_data = calculate_yearly_data(@year)
  end
  
  private
  
  def calculate_monthly_revenue(year, month)
    # Get all paid or partially paid bills for the specified month and sum their amounts
    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month
    
    Bill.where("billing_date BETWEEN ? AND ?", start_date, end_date)
        .where(status: ['paid', 'partial'])
        .sum(:total_amount)
  end
  
  def calculate_monthly_expenses(year, month)
    # Get all operating expenses for the specified month and sum their amounts
    OperatingExpense.for_month(year, month).sum(:amount)
  end
  
  def calculate_yearly_data(year)
    # Initialize data structure for the chart
    data = {
      months: [],
      revenue: [],
      expenses: [],
      profit: []
    }
    
    # Calculate revenue, expenses and profit for each month of the selected year
    (1..12).each do |month|
      # Skip future months
      next if Date.new(year, month, 1) > Date.today
      
      # Add month name
      data[:months] << I18n.l(Date.new(year, month, 1), format: '%b')
      
      # Calculate revenue for the month
      monthly_revenue = calculate_monthly_revenue(year, month)
      data[:revenue] << monthly_revenue
      
      # Calculate expenses for the month
      monthly_expenses = calculate_monthly_expenses(year, month)
      data[:expenses] << monthly_expenses
      
      # Calculate profit for the month
      data[:profit] << (monthly_revenue - monthly_expenses)
    end
    
    data
  end
end
