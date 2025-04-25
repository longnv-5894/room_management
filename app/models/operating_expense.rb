class OperatingExpense < ApplicationRecord
  belongs_to :building, optional: true
  validates :category, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :expense_date, presence: true

  # Common expense categories
  CATEGORY_KEYS = [
    'utilities', 
    'maintenance', 
    'repairs', 
    'cleaning', 
    'security', 
    'insurance', 
    'taxes', 
    'staff_salary',
    'electric',
    'water',
    'internet',
    'rent',
    'miscellaneous'
  ].freeze

  # Return translated categories for select options
  def self.categories_for_select
    CATEGORY_KEYS.map { |key| [I18n.t("operating_expenses.categories.#{key}"), key] }
  end

  # Return translated category name
  def category_name
    I18n.t("operating_expenses.categories.#{category}", default: category)
  end

  # Scope for monthly expenses
  scope :for_month, ->(year, month) {
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    where(expense_date: start_date..end_date)
  }

  scope :for_building, ->(building_id) {
    where(building_id: building_id)
  }

  # Calculate total expenses for a given month and year
  def self.total_for_month(year, month)
    for_month(year, month).sum(:amount)
  end

  # Calculate total expenses for a given month, year and building
  def self.total_for_month_and_building(year, month, building_id)
    for_month(year, month).for_building(building_id).sum(:amount)
  end
end
