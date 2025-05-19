class Room < ApplicationRecord
  belongs_to :building, optional: true
  has_many :room_assignments, dependent: :destroy
  has_many :tenants, through: :room_assignments
  has_many :utility_readings, dependent: :destroy

  validates :number, presence: true, uniqueness: { scope: :building_id }

  enum :status, { available: "available", occupied: "occupied", maintenance: "maintenance" }

  # Ghi đè phương thức initialize để loại bỏ thuộc tính monthly_rent
  def initialize(attributes = nil)
    attributes = attributes.except(:monthly_rent, "monthly_rent") if attributes
    super
  end

  # Ghi đè phương thức mass assignment để loại bỏ monthly_rent khỏi các thuộc tính
  def attributes=(attributes)
    attributes = attributes.except(:monthly_rent, "monthly_rent") if attributes
    super
  end

  # Display name for room with building
  def full_name
    building_name = building ? "#{building.name} - " : ""
    "#{building_name}Room #{number}"
  end

  def current_assignments
    room_assignments.where(active: true)
  end

  def current_assignment
    current_assignments.first
  end

  def current_tenant
    current_assignment&.tenant
  end

  def current_tenants
    tenants.joins(:room_assignments).where(room_assignments: { active: true, room_id: id })
  end

  def occupied?
    status == "occupied"
  end

  def bills
    Bill.joins(:room_assignment).where(room_assignments: { room_id: id }).order(billing_date: :desc)
  end

  # Phương thức mới để lấy giá phòng gần nhất từ các room assignments
  def latest_monthly_rent
    # Ưu tiên lấy giá từ room_assignment có is_representative_tenant = true
    representative_assignment = room_assignments.where(active: true, is_representative_tenant: true).order(start_date: "desc").first
    return representative_assignment.monthly_rent if representative_assignment&.monthly_rent.present?

    # Nếu không có representative tenant, lấy từ assignment hoạt động gần nhất
    active_assignment = room_assignments.where(active: true).order(created_at: :desc).first
    return active_assignment.monthly_rent if active_assignment&.monthly_rent.present?

    # Nếu không có assignment hoạt động, lấy từ assignment gần nhất (kể cả đã kết thúc)
    latest_assignment = room_assignments.order(created_at: :desc).first
    return latest_assignment.monthly_rent if latest_assignment&.monthly_rent.present?

    # Nếu không có room_assignment nào, trả về 0
    0
  end
end
