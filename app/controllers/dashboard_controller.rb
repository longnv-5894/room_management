class DashboardController < ApplicationController
  before_action :require_login

  def index
    @rooms = Room.all
    @vacant_rooms = Room.where(status: 'available').count
    @occupied_rooms = Room.where(status: 'occupied').count
    @tenants_count = Tenant.count
    @recent_bills = Bill.order(created_at: :desc).limit(5)
    @unpaid_bills_count = Bill.where(status: 'unpaid').count
    @monthly_revenue = Bill.where('EXTRACT(MONTH FROM billing_date) = ? AND EXTRACT(YEAR FROM billing_date) = ?', 
                                  Date.today.month, Date.today.year).sum(:total_amount)
  end

  private

  def require_login
    unless session[:user_id]
      flash[:danger] = "Please log in to access this page"
      redirect_to login_path
    end
  end
end
