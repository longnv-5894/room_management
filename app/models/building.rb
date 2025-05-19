class Building < ApplicationRecord
  belongs_to :user
  belongs_to :country, optional: true
  belongs_to :city, optional: true
  belongs_to :district, optional: true
  belongs_to :ward, optional: true
  has_many :rooms, dependent: :destroy
  has_many :operating_expenses, dependent: :destroy
  has_many :utility_prices, dependent: :nullify
  has_many :smart_devices, dependent: :nullify
  has_many :import_histories, dependent: :destroy

  validates :name, presence: true
  # We're keeping address validation temporarily until data migration is complete
  validates :address, presence: true

  # Building status options
  STATUSES = [ "active", "under_construction", "renovation", "inactive" ].freeze

  enum :status, STATUSES.zip(STATUSES).to_h, default: "active"

  # Return translated statuses for select options
  def self.statuses_for_select
    STATUSES.map { |key| [ I18n.t("buildings.statuses.#{key}"), key ] }
  end

  # Return full address combining all components
  def full_address
    components = []
    components << street_address if street_address.present?
    components << ward.name if ward.present?
    components << district.name if district.present?
    components << city.name if city.present?
    components << country.name if country.present?
    components.compact.join(", ")
  end

  # Return total number of rooms
  def total_rooms
    rooms.count
  end

  # Return total number of tenants
  def total_tenants
    rooms.joins(:room_assignments).where(room_assignments: { active: true }).count
  end

  # Return occupancy rate
  def occupancy_rate
    return 0 if total_rooms == 0
    (rooms.where(status: "occupied").count.to_f / total_rooms) * 100
  end

  # Return total monthly revenue potential
  def total_monthly_revenue_potential
    rooms.sum(:monthly_rent)
  end

  # Return actual monthly revenue
  def actual_monthly_revenue
    # Get the current month and year
    current_date = Date.today
    current_month = current_date.month
    current_year = current_date.year

    # Get all bills from rooms in this building for the current month
    Bill.joins(room_assignment: :room)
        .where(rooms: { building_id: id })
        .where("extract(month from billing_date) = ?", current_month)
        .where("extract(year from billing_date) = ?", current_year)
        .where(status: [ "paid", "partial" ])
        .sum(:total_amount)
  end

  def operating_expenses
    OperatingExpense.where(building_id: id)
  end

  # Tính tổng giá trị tiền thuê hàng tháng
  def total_rent
    # Tính tổng từ room_assignments thay vì rooms
    # Chỉ tính các room_assignments đang active (còn hiệu lực)
    RoomAssignment.joins(:room)
                 .where(active: true, rooms: { building_id: id })
                 .sum(:monthly_rent)
  end
end
