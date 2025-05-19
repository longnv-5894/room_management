class ImportHistory < ApplicationRecord
  belongs_to :building
  belongs_to :user, optional: true

  # Thay đổi cách serialize để phù hợp với Rails 8.0+
  serialize :imported_count, coder: YAML
  serialize :import_params, coder: YAML

  validates :file_name, presence: true
  validates :import_date, presence: true
  validates :status, presence: true

  # Trạng thái của quá trình import
  enum :status, {
    success: "success",    # Import thành công
    partial: "partial",    # Import một phần (có lỗi)
    failed: "failed",      # Import thất bại hoàn toàn
    reverted: "reverted"   # Đã được revert
  }

  # Tạo mới một bản ghi lịch sử import
  def self.create_from_import(building, file_path, import_service, user = nil, status = "success", notes = nil)
    create(
      building: building,
      file_name: File.basename(file_path),
      file_path: file_path,
      import_date: Time.current,
      user: user,
      status: status,
      imported_count: import_service.imported_count,
      notes: notes || import_service.errors.join(", "),
      import_params: {
        billing_month: import_service.billing_month,
        billing_year: import_service.billing_year,
        created_room_assignments: import_service.created_room_assignments,
        updated_room_assignments: import_service.updated_room_assignments,
        created_rooms: import_service.created_rooms,
        created_tenants: import_service.created_tenants
      }
    )
  end

  # Revert lại dữ liệu đã import từ lịch sử này
  def revert!
    return false if status == "reverted"

    begin
      ActiveRecord::Base.transaction do
        # Lấy dữ liệu billing_period từ import_params
        billing_month = import_params["billing_month"] || import_params[:billing_month]
        billing_year = import_params["billing_year"] || import_params[:billing_year]

        if billing_month.present? && billing_year.present?
          billing_date = Date.new(billing_year.to_i, billing_month.to_i, 1)
          # Tính ngày tháng trước để revert cả chỉ số đầu kỳ
          previous_month_date = billing_date - 1.month

          # Log thông tin revert
          Rails.logger.info "Starting revert for ImportHistory ##{id} (#{billing_month}/#{billing_year})"

          # Revert bills cho building và tháng đã import
          revert_bills(billing_date)

          # Revert utility readings cho cả tháng hiện tại và tháng trước
          revert_utility_readings(billing_date)
          revert_utility_readings(previous_month_date)

          # Revert operating expenses
          revert_operating_expenses(billing_date)

          # Revert utility prices
          revert_utility_prices(billing_date)

          # Revert vehicles nếu có
          if imported_count.is_a?(Hash) && imported_count["vehicles"].to_i > 0
            revert_vehicles
          end

          # Revert room assignments mới được tạo trong quá trình import
          revert_room_assignments

          # Revert rooms mới được tạo trong quá trình import
          revert_rooms

          # Revert tenants mới được tạo trong quá trình import
          # revert_tenants

          # Cập nhật trạng thái đã revert
          self.status = "reverted"
          self.notes = notes.present? ? "#{notes} | Reverted at #{Time.current}" : "Reverted at #{Time.current}"
          self.save!

          Rails.logger.info "Successfully reverted ImportHistory ##{id}"
        else
          errors.add(:base, "Không thể revert: Thiếu thông tin tháng/năm của lần import")
          return false
        end
      end

      true
    rescue => e
      errors.add(:base, "Lỗi khi revert: #{e.message}")
      Rails.logger.error "Revert error for ImportHistory ##{id}: #{e.message}\n#{e.backtrace.join("\n")}"
      false
    end
  end

  private

  # Xóa hóa đơn liên quan đến kỳ hóa đơn này
  def revert_bills(billing_date)
    # Lấy tất cả các room của building
    room_ids = building.rooms.pluck(:id)

    # Tìm các room_assignment của các room này
    room_assignment_ids = RoomAssignment.where(room_id: room_ids).pluck(:id)

    # Xóa bills của tháng đã import
    bills_to_delete = Bill.where(
      room_assignment_id: room_assignment_ids,
      billing_date: billing_date
    )

    # Ghi log số lượng bill sẽ bị xóa
    count = bills_to_delete.count
    Rails.logger.info "Reverting #{count} bills for billing date #{billing_date}"

    bills_to_delete.destroy_all
  end

  # Xóa các chỉ số công tơ liên quan đến kỳ hóa đơn này
  def revert_utility_readings(billing_date)
    # Lấy tất cả các room của building
    room_ids = building.rooms.pluck(:id)

    # Xóa utility readings của tháng đã import
    readings_to_delete = UtilityReading.where(
      room_id: room_ids,
      reading_date: billing_date
    )

    # Ghi log số lượng readings sẽ bị xóa
    count = readings_to_delete.count
    Rails.logger.info "Reverting #{count} utility readings for reading date #{billing_date}"

    readings_to_delete.destroy_all
  end

  # Xóa các khoản chi liên quan đến kỳ hóa đơn này
  def revert_operating_expenses(billing_date)
    # Xóa operating expenses của tháng đã import
    expenses_to_delete = OperatingExpense.where(
      building_id: building.id,
      expense_date: billing_date
    )

    # Ghi log số lượng expenses sẽ bị xóa
    count = expenses_to_delete.count
    Rails.logger.info "Reverting #{count} operating expenses for expense date #{billing_date}"

    expenses_to_delete.destroy_all
  end

  # Xóa cài đặt giá dịch vụ liên quan đến kỳ hóa đơn này
  def revert_utility_prices(billing_date)
    # Xóa utility prices của tháng đã import
    prices_to_delete = UtilityPrice.where(
      building_id: building.id,
      effective_date: billing_date
    )

    # Ghi log số lượng prices sẽ bị xóa
    count = prices_to_delete.count
    Rails.logger.info "Reverting #{count} utility prices for effective date #{billing_date}"

    prices_to_delete.destroy_all
  end

  # Xóa các phương tiện đã được tạo trong lần import này
  def revert_vehicles
    # Chỉ revert các phương tiện được tạo trong khoảng thời gian xung quanh thời điểm import
    # (1 giờ trước và sau thời điểm import)
    time_range = (import_date - 1.hour)..(import_date + 1.hour)

    # Lấy tất cả tenant trong tòa nhà này
    tenant_ids = Tenant.joins(room_assignments: :room)
                      .where(rooms: { building_id: building.id })
                      .pluck(:id)
                      .uniq

    # Tìm và xóa các phương tiện của các tenant này được tạo trong khoảng thời gian import
    vehicles_to_delete = Vehicle.where(
      tenant_id: tenant_ids,
      created_at: time_range,
      notes: "Imported from Excel"
    )

    count = vehicles_to_delete.count
    Rails.logger.info "Reverting #{count} vehicles created during import"

    vehicles_to_delete.destroy_all
  end

  # Xóa các room assignments mới được tạo trong quá trình import
  def revert_room_assignments
    # Lấy danh sách ID của các room assignments mới tạo
    created_room_assignment_ids = import_params["created_room_assignments"] || import_params[:created_room_assignments] || []

    if created_room_assignment_ids.present?
      # Lấy danh sách các room assignments mới tạo
      room_assignments_to_delete = RoomAssignment.where(id: created_room_assignment_ids)

      # Ghi log số lượng room assignments sẽ bị xóa
      count = room_assignments_to_delete.count
      Rails.logger.info "Reverting #{count} newly created room assignments from import"


      # Xóa hóa đơn liên quan đến các room assignment này trước
      related_bills = Bill.where(room_assignment_id: created_room_assignment_ids)
      if related_bills.any?
        Rails.logger.info "Deleting #{related_bills.count} bills related to reverting room assignments"
        related_bills.destroy_all
      end

      # Sau đó xóa các room assignments mới tạo
      room_assignments_to_delete.destroy_all

    else
      Rails.logger.info "No newly created room assignments to revert"
    end
  end

  # Xóa các phòng mới được tạo trong quá trình import
  def revert_rooms
    # Lấy danh sách ID của các phòng mới tạo
    created_room_ids = import_params["created_rooms"] || import_params[:created_rooms] || []

    if created_room_ids.present?
      # Lấy danh sách các phòng mới tạo
      rooms_to_check = Room.where(id: created_room_ids)

      rooms_to_delete = []

      # Lấy tháng và năm billing để kiểm tra utility readings
      billing_month = import_params["billing_month"] || import_params[:billing_month]
      billing_year = import_params["billing_year"] || import_params[:billing_year]

      # Tạo mảng ngày tháng để kiểm tra
      reading_dates = []
      if billing_month.present? && billing_year.present?
        current_month_date = Date.new(billing_year.to_i, billing_month.to_i, 1)
        reading_dates << current_month_date

        # Chỉ thêm tháng trước nếu tháng hiện tại không phải là tháng 1
        if billing_month.to_i > 1
          reading_dates << Date.new(billing_year.to_i, billing_month.to_i - 1, 1)
        else
          # Nếu là tháng 1, thì tháng trước là tháng 12 năm trước
          reading_dates << Date.new(billing_year.to_i - 1, 12, 1)
        end
      end

      # Kiểm tra từng phòng có thể xóa không
      rooms_to_check.each do |room|
        # Kiểm tra xem phòng có còn liên kết với dữ liệu khác không
        has_utility_readings = false

        if reading_dates.present?
          # Nếu có thông tin tháng/năm, kiểm tra xem có utility readings không phải tháng hiện tại và tháng trước không
          has_utility_readings = UtilityReading.where(room_id: room.id)
                                           .where.not(reading_date: reading_dates)
                                           .exists?
        else
          # Nếu không có thông tin tháng/năm, kiểm tra tất cả utility readings
          has_utility_readings = UtilityReading.where(room_id: room.id).exists?
        end

        # Kiểm tra xem có các room assignments không được tạo trong lần import này
        created_room_assignment_ids = import_params["created_room_assignments"] || import_params[:created_room_assignments] || []
        other_room_assignments = RoomAssignment.where(room_id: room.id)

        if created_room_assignment_ids.present?
          other_room_assignments = other_room_assignments.where.not(id: created_room_assignment_ids)
        end

        other_room_assignments_count = other_room_assignments.count

        # Nếu không có dữ liệu liên quan khác, đánh dấu phòng để xóa
        if !has_utility_readings && other_room_assignments_count == 0
          rooms_to_delete << room.id
        end
      end

      # Ghi log số lượng phòng sẽ bị xóa
      count = rooms_to_delete.size
      Rails.logger.info "Reverting #{count} newly created rooms from import"

      if count > 0
        # Xóa các phòng
        Room.where(id: rooms_to_delete).destroy_all
      end
    else
      Rails.logger.info "No newly created rooms to revert"
    end
  end

  # Xóa các tenant mới được tạo trong quá trình import
  def revert_tenants
    # Lấy danh sách ID của các tenant mới tạo
    created_tenant_ids = import_params["created_tenants"] || import_params[:created_tenants] || []

    if created_tenant_ids.present?
      # Lấy danh sách các tenant để kiểm tra
      tenants_to_check = Tenant.where(id: created_tenant_ids)

      # Mảng lưu ID các tenant có thể xóa an toàn
      tenants_to_delete = []

      # Kiểm tra từng tenant có thể xóa không
      tenants_to_check.each do |tenant|
        # Kiểm tra xem tenant có room_assignments nào không thuộc danh sách được tạo trong lần import này
        created_room_assignment_ids = import_params["created_room_assignments"] || import_params[:created_room_assignments] || []
        other_room_assignments = RoomAssignment.where(tenant_id: tenant.id)

        if created_room_assignment_ids.present?
          other_room_assignments = other_room_assignments.where.not(id: created_room_assignment_ids)
        end

        # Kiểm tra xem tenant có liên kết với vehicles nào không
        has_vehicles = Vehicle.where(tenant_id: tenant.id).exists?

        # Kiểm tra xem tenant có liên kết với contracts nào không (nếu có model này)
        has_contracts = defined?(Contract) && Contract.where(tenant_id: tenant.id).exists?

        # Kiểm tra xem tenant có liên kết với payments nào không (nếu có model này)
        has_payments = defined?(Payment) && Payment.where(tenant_id: tenant.id).exists?

        # Nếu tenant không có liên kết nào với dữ liệu khác ngoài room_assignments đã được tạo trong lần import này,
        # thì có thể xóa an toàn
        if other_room_assignments.count == 0 && !has_vehicles && !has_contracts && !has_payments
          tenants_to_delete << tenant.id
        end
      end

      # Ghi log số lượng tenant sẽ bị xóa
      count = tenants_to_delete.size
      Rails.logger.info "Reverting #{count} newly created tenants from import"

      if count > 0
        # Xóa các tenant
        Tenant.where(id: tenants_to_delete).destroy_all
      end
    else
      Rails.logger.info "No newly created tenants to revert"
    end
  end
end
