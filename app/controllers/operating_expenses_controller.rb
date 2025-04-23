class OperatingExpensesController < ApplicationController
  before_action :set_operating_expense, only: [:show, :edit, :update, :destroy]
  
  def index
    # Default to current month if no month/year provided
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    
    @date = Date.new(@year, @month, 1)
    @operating_expenses = OperatingExpense.for_month(@year, @month).order(expense_date: :desc)
    @total_amount = @operating_expenses.sum(:amount)
    
    # Group expenses by category for reporting
    # Fixed the pluck to use proper SQL result extraction
    @expenses_by_category = {}
    category_totals = OperatingExpense.for_month(@year, @month)
                                      .group(:category)
                                      .sum(:amount)
    @expenses_by_category = category_totals
  end
  
  def show
  end
  
  def new
    @operating_expense = OperatingExpense.new(expense_date: Date.today)
  end
  
  def create
    @operating_expense = OperatingExpense.new(operating_expense_params)
    
    if @operating_expense.save
      redirect_to operating_expenses_path(year: @operating_expense.expense_date.year, month: @operating_expense.expense_date.month), 
                  notice: t('operating_expenses.create_success')
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @operating_expense.update(operating_expense_params)
      redirect_to operating_expenses_path(year: @operating_expense.expense_date.year, month: @operating_expense.expense_date.month), 
                  notice: t('operating_expenses.update_success')
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    year = @operating_expense.expense_date.year
    month = @operating_expense.expense_date.month
    
    @operating_expense.destroy
    redirect_to operating_expenses_path(year: year, month: month), 
                notice: t('operating_expenses.delete_success')
  end
  
  private
  
  def set_operating_expense
    @operating_expense = OperatingExpense.find(params[:id])
  end
  
  def operating_expense_params
    params.require(:operating_expense).permit(:category, :description, :amount, :expense_date)
  end
end
