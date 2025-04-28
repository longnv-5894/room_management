class OperatingExpensesController < ApplicationController
  before_action :require_login
  before_action :set_operating_expense, only: [:show, :edit, :update, :destroy]
  before_action :set_building, only: [:index, :new, :create]
  
  def index
    # Default to current month if no month/year provided
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    
    @date = Date.new(@year, @month, 1)
    
    # Filter expenses by building if specified
    if @building
      @operating_expenses = @building.operating_expenses.for_month(@year, @month).order(expense_date: :desc)
      @total_amount = @operating_expenses.sum(:amount)
      
      # Group expenses by category for reporting - use a separate base query to avoid inheriting ORDER BY
      @expenses_by_category = OperatingExpense.unscoped.for_month(@year, @month)
                                         .where(building_id: @building.id)
                                         .group(:category)
                                         .sum(:amount)
      
      render 'building_expenses'
    else
      @operating_expenses = OperatingExpense.for_month(@year, @month).order(expense_date: :desc)
      @total_amount = @operating_expenses.sum(:amount)
      
      # Group expenses by category for reporting - use unscoped to avoid inheriting any default scopes
      @expenses_by_category = OperatingExpense.unscoped.for_month(@year, @month)
                                         .group(:category)
                                         .sum(:amount)
      
      # Group expenses by building for reporting - use unscoped to avoid inheriting any default scopes
      @expenses_by_building = OperatingExpense.unscoped.for_month(@year, @month)
                                         .joins('LEFT JOIN buildings ON operating_expenses.building_id = buildings.id')
                                         .group('COALESCE(buildings.name, \'General\')')
                                         .sum(:amount)
    end
  end
  
  def show
  end
  
  def new
    @operating_expense = OperatingExpense.new(expense_date: Date.today)
    @operating_expense.building = @building if @building
  end
  
  def create
    @operating_expense = OperatingExpense.new(operating_expense_params)
    
    if @operating_expense.save
      if @building
        redirect_to building_operating_expenses_path(@building, year: @operating_expense.expense_date.year, month: @operating_expense.expense_date.month), 
                   notice: t('operating_expenses.create_success')
      else
        redirect_to operating_expenses_path(year: @operating_expense.expense_date.year, month: @operating_expense.expense_date.month), 
                   notice: t('operating_expenses.create_success')
      end
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @operating_expense.update(operating_expense_params)
      if @operating_expense.building
        redirect_to building_operating_expenses_path(@operating_expense.building, year: @operating_expense.expense_date.year, month: @operating_expense.expense_date.month), 
                   notice: t('operating_expenses.update_success')
      else
        redirect_to operating_expenses_path(year: @operating_expense.expense_date.year, month: @operating_expense.expense_date.month), 
                   notice: t('operating_expenses.update_success')
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    year = @operating_expense.expense_date.year
    month = @operating_expense.expense_date.month
    building = @operating_expense.building
    
    @operating_expense.destroy
    
    if building
      redirect_to building_operating_expenses_path(building, year: year, month: month), 
                 notice: t('operating_expenses.delete_success')
    else
      redirect_to operating_expenses_path(year: year, month: month), 
                 notice: t('operating_expenses.delete_success')
    end
  end
  
  private
  
  def set_operating_expense
    @operating_expense = OperatingExpense.find(params[:id])
  end
  
  def set_building
    @building = Building.find(params[:building_id]) if params[:building_id]
  end
  
  def operating_expense_params
    params.require(:operating_expense).permit(:category, :description, :amount, :expense_date, :building_id, :notes)
  end
  
  def require_login
    unless session[:user_id]
      flash[:danger] = t('auth.login_required')
      redirect_to login_path
    end
  end
end
