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
    @vacant_rooms = Room.where(status: 'available').count
    @occupied_rooms = Room.where(status: 'occupied').count
    @tenants_count = Tenant.count
    
    # Financial information
    @recent_bills = Bill.order(created_at: :desc).limit(5)
    @unpaid_bills_count = Bill.where(status: 'unpaid').count
    @monthly_revenue = Bill.where('EXTRACT(MONTH FROM billing_date) = ? AND EXTRACT(YEAR FROM billing_date) = ?', 
                                  Date.today.month, Date.today.year).sum(:total_amount)
    
    # Monthly expenses
    @monthly_expenses = OperatingExpense.respond_to?(:for_month) ? 
                        OperatingExpense.for_month(Date.today.year, Date.today.month).sum(:amount) : 0
    @monthly_profit = @monthly_revenue - @monthly_expenses
  end

  private

  def require_login
    unless session[:user_id]
      flash[:danger] = t('auth.login_required') 
      redirect_to login_path
      return false
    end
  end
end
