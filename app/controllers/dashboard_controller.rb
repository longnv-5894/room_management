class DashboardController < ApplicationController
  before_action :require_login

  def index
    # User's buildings
    if current_user
      @buildings_count = current_user.buildings.count
      @buildings = current_user.buildings.order(created_at: :desc).limit(3)
    else
      @buildings_count = 0
      @buildings = []
    end

    # Room statistics
    @rooms = Room.all
    @vacant_rooms = Room.where(status: "available").count
    @occupied_rooms = Room.where(status: "occupied").count
    @tenants_count = Tenant.count

    # Financial information
    @recent_bills = Bill.order(created_at: :desc).limit(5)
    @unpaid_bills_count = Bill.where(status: "unpaid").count

    # All-time revenue calculations instead of monthly
    @all_time_revenue = Bill.sum(:total_amount)

    # All-time expenses
    @all_time_expenses = OperatingExpense.sum(:amount)
    @all_time_profit = @all_time_revenue - @all_time_expenses

    # Calculate profit margin percentage
    @profit_margin = @all_time_revenue > 0 ? (@all_time_profit.to_f / @all_time_revenue * 100).round(2) : 0
  end

  private

  def require_login
    unless session[:user_id]
      flash[:danger] = t("auth.login_required")
      redirect_to login_path
      false
    end
  end
end
