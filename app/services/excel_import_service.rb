class ExcelImportService
  attr_reader :file_path, :building, :errors, :imported_count, :billing_month, :billing_year

  def initialize(file_path, building)
    @file_path = file_path
    @building = building
    @errors = []
    @imported_count = { rooms: 0, tenants: 0, utility_readings: 0, bills: 0, expenses: 0, utility_prices: 0, vehicles: 0 }
    @billing_month = nil
    @billing_year = nil
    @column_indices = {}
    @tenant_cache = {} # Cache để tránh truy vấn lại tenant nhiều lần
  end

  def import
    return false unless valid_file?

    begin
      # Sử dụng caching để tăng tốc độ xử lý
      ActiveRecord::Base.transaction do
        spreadsheet = Roo::Spreadsheet.open(file_path)

        # Trích xuất tháng/năm từ tên file nếu có
        extract_period_from_filename(file_path)

        # Process first sheet (room data)
        sheet = spreadsheet.sheet(0)
        process_room_data(sheet)

        # Process operating expenses (second sheet) if available
        if spreadsheet.sheets.length > 1
          expenses_sheet = spreadsheet.sheet(1)
          process_operating_expenses(expenses_sheet)
        end

        # Process utility prices (third sheet) if available
        if spreadsheet.sheets.length > 2
          utility_prices_sheet = spreadsheet.sheet(2)
          process_utility_prices(utility_prices_sheet)
        end

        # If we have any errors, raise an exception to trigger a rollback
        unless @errors.empty?
          raise ActiveRecord::Rollback, "Import errors: #{@errors.join(', ')}"
        end
      end

      # If we've made it here without raising an exception, the transaction was successful
      @errors.empty?
    rescue => e
      @errors << "Error processing file: #{e.message}"
      Rails.logger.error "Excel import exception: #{e.backtrace.join("\n")}" # For debugging
      false
    end
  end

  private

  def extract_period_from_filename(file_path)
    filename = File.basename(file_path, ".*")

    # Mẫu phổ biến: "Tính tiền nhà trọ tháng 4-2025" hoặc "Nhà trọ 04/2025"
    if filename =~ /tháng\s*(\d{1,2})[\-\/\._](\d{4})/i
      @billing_month = $1.to_i
      @billing_year = $2.to_i
      Rails.logger.info "Extracted billing period from filename: #{@billing_month}/#{@billing_year}"
    elsif filename =~ /(\d{1,2})[\-\/\._](\d{4})/
      @billing_month = $1.to_i
      @billing_year = $2.to_i
      Rails.logger.info "Extracted billing period from filename with numbers only: #{@billing_month}/#{@billing_year}"
    end
  end

  def process_room_data(sheet)
    # Map the column headers to indices - headers are in rows 4 and 5
    map_column_headers(sheet)

    # Extract billing month/year from sheet data if not found from filename
    if @billing_month.nil? || @billing_year.nil?
      extract_billing_period_from_data(sheet)
    end

    # Start from row 6 (after header rows)
    ((sheet.first_row + 5)..sheet.last_row).each do |row_index|
      row = sheet.row(row_index)
      import_row(row) unless empty_row?(row)
    end
  end

  def process_operating_expenses(sheet)
    Rails.logger.info "Processing operating expenses sheet"

    # Find the expense categories and amounts columns
    expense_category_col = nil
    expense_amount_col = nil

    # Look through the first few rows to identify the column headers
    (1..10).each do |row_idx|
      row = sheet.row(row_idx)
      next if empty_row?(row)

      row.each_with_index do |cell, col_idx|
        cell_text = cell.to_s.strip.downcase
        if cell_text.include?("khoản chi") || cell_text.include?("expense") || cell_text.include?("chi phí")
          expense_category_col = col_idx
        elsif cell_text.include?("số tiền") || cell_text.include?("amount") || cell_text.include?("tiền")
          expense_amount_col = col_idx
        end
      end

      break if expense_category_col && expense_amount_col
    end

    # Nếu không tìm thấy các cột bằng cách tìm kiếm trong header, thử sử dụng cột A và B như các cột mặc định
    if expense_category_col.nil? && expense_amount_col.nil?
      # Kiểm tra xem cột A và B có dữ liệu không
      has_data_in_columns = false
      (1..10).each do |row_idx|
        row = sheet.row(row_idx)
        next if empty_row?(row)
        if row[0].present? && row[0].to_s.downcase.include?("tiền") && row[1].present? && row[1].to_i > 0
          has_data_in_columns = true
          break
        end
      end

      if has_data_in_columns
        Rails.logger.info "Using default columns A and B for expense category and amount"
        expense_category_col = 0  # Cột A
        expense_amount_col = 1    # Cột B
      end
    end

    Rails.logger.info "Found expense columns - Category: #{expense_category_col}, Amount: #{expense_amount_col}"
    return if expense_category_col.nil? || expense_amount_col.nil?

    # Xử lý tất cả các hàng trong sheet
    (1..sheet.last_row).each do |row_idx|
      row = sheet.row(row_idx)
      next if empty_row?(row)

      category = row[expense_category_col].to_s.strip
      # Đảm bảo giá trị tiền được chuyển đổi đúng cách
      amount_raw = row[expense_amount_col]
      amount = 0

      # Xử lý cả giá trị số và chuỗi chứa số
      if amount_raw.is_a?(Numeric)
        amount = amount_raw.to_i
      elsif amount_raw.to_s.strip.match(/^[\d\.,]+$/)
        amount = amount_raw.to_s.gsub(/[^\d\.]/, "").to_i
      end

      # Skip total rows or empty categories
      next if category.blank? || amount <= 0
      next if category.downcase.include?("tổng") || category.downcase.include?("total")

      # Map category to system category
      expense_category = map_expense_category(category)

      Rails.logger.info "Found expense: #{category} => #{expense_category} - #{amount}"

      # Kiểm tra xem chi phí đã tồn tại chưa
      existing_expense = OperatingExpense.find_by(
        building: @building,
        category: expense_category,
        expense_date: Date.new(@billing_year || Date.today.year, @billing_month || Date.today.month, 1),
        description: category
      )

      if existing_expense
        # Cập nhật nếu đã tồn tại
        existing_expense.amount = amount
        if existing_expense.save
          Rails.logger.info "Updated existing operating expense: #{existing_expense.category} - #{existing_expense.amount}"
        else
          @errors << "Failed to update operating expense #{category}: #{existing_expense.errors.full_messages.join(', ')}"
        end
      else
        # Tạo mới nếu chưa tồn tại
        expense = OperatingExpense.new(
          building: @building,
          category: expense_category,
          amount: amount,
          expense_date: Date.new(@billing_year || Date.today.year, @billing_month || Date.today.month, 1),
          description: category
        )

        if expense.save
          @imported_count[:expenses] += 1
          Rails.logger.info "Successfully created operating expense: #{expense.category} - #{expense.amount}"
        else
          @errors << "Failed to create operating expense #{category}: #{expense.errors.full_messages.join(', ')}"
        end
      end
    end
  end

  def map_expense_category(category)
    category = category.to_s.strip.downcase

    mapping = {
      /tiền điện|điện|electricity|electric|chi phí điện|điện năng|phí điện/i => "electric",
      /tiền nước|nước|water/i => "water",
      /tiền mạng|mạng|internet|wifi/i => "internet",
      /tiền vệ sinh|vệ sinh|dọn dẹp|clean/i => "cleaning",
      /tiền rác|rác|garbage|trash/i => "miscellaneous",
      /sửa chữa|repair/i => "repairs",
      /bảo trì|maintenance/i => "maintenance",
      /an ninh|bảo vệ|security/i => "security",
      /bảo hiểm|insurance/i => "insurance",
      /thuế|tax/i => "taxes",
      /lương|nhân viên|salary/i => "staff_salary",
      /thuê|thầu|rent/i => "rent"
    }

    mapping.each do |pattern, mapped_category|
      return mapped_category if category.match?(pattern)
    end

    Rails.logger.warn "Unrecognized expense category: '#{category}', defaulting to 'miscellaneous'"
    "miscellaneous" # Default category
  end

  def process_utility_prices(sheet)
    Rails.logger.info "Processing utility prices sheet"

    # Look for utility price settings in the sheet
    electricity_rate = nil
    water_rate = nil
    service_fee = nil

    # Scan the sheet for the utility price settings
    1.upto(sheet.last_row) do |row_idx|
      row = sheet.row(row_idx)
      next if empty_row?(row)

      row.each_with_index do |cell, col_idx|
        cell_text = cell.to_s.strip.downcase

        if cell_text.include?("tiền điện") || cell_text.include?("electricity") || cell_text.include?("giá điện")
          # Look for the rate value in the next column
          rate_value = row[col_idx + 1].to_i if row[col_idx + 1]
          electricity_rate = rate_value if rate_value && rate_value > 0
        elsif cell_text.include?("tiền nước") || cell_text.include?("water") || cell_text.include?("giá nước")
          rate_value = row[col_idx + 1].to_i if row[col_idx + 1]
          water_rate = rate_value if rate_value && rate_value > 0
        elsif cell_text.include?("phí dịch vụ") || cell_text.include?("service") || cell_text.include?("dịch vụ")
          rate_value = row[col_idx + 1].to_i if row[col_idx + 1]
          service_fee = rate_value if rate_value && rate_value > 0
        end
      end
    end

    if electricity_rate || water_rate || service_fee
      Rails.logger.info "Found utility prices - Electricity: #{electricity_rate}, Water: #{water_rate}, Service: #{service_fee}"

      # Kiểm tra xem đã có cài đặt giá dịch vụ cho tháng này chưa
      existing_price = UtilityPrice.where(
        building: @building,
        effective_date: Date.new(@billing_year || Date.today.year, @billing_month || Date.today.month, 1)
      ).first

      if existing_price
        # Cập nhật nếu đã tồn tại
        if electricity_rate && electricity_rate > 0
          existing_price.electricity_unit_price = electricity_rate
        end
        if water_rate && water_rate > 0
          existing_price.water_unit_price = water_rate
        end
        if service_fee && service_fee > 0
          existing_price.service_charge = service_fee
        end

        if existing_price.save
          Rails.logger.info "Successfully updated utility price settings"
        else
          @errors << "Failed to update utility price settings: #{existing_price.errors.full_messages.join(', ')}"
        end
      else
        # Create a new utility price record
        utility_price = UtilityPrice.new(
          building: @building,
          electricity_unit_price: electricity_rate || 0,
          water_unit_price: water_rate || 0,
          service_charge: service_fee || 0,
          effective_date: Date.new(@billing_year || Date.today.year, @billing_month || Date.today.month, 1),
          notes: "Imported from Excel file for #{@billing_month}/#{@billing_year}"
        )

        if utility_price.save
          @imported_count[:utility_prices] += 1
          Rails.logger.info "Successfully created utility price settings"
        else
          @errors << "Failed to create utility price settings: #{utility_price.errors.full_messages.join(', ')}"
        end
      end
    end
  end

  def valid_file?
    unless File.exist?(file_path)
      @errors << "File not found: #{file_path}"
      return false
    end

    extension = File.extname(file_path).downcase
    unless [ ".xlsx", ".xls" ].include?(extension)
      @errors << "Invalid file format. Please upload an Excel file (.xlsx or .xls)"
      return false
    end

    true
  end

  def extract_billing_period_from_data(sheet)
    # Default to current date
    current_date = Date.today
    @billing_month ||= current_date.month
    @billing_year ||= current_date.year

    # First check A2, which often contains date information in the excel format
    begin
      a2_value = sheet.cell(2, 1)
      if a2_value.is_a?(Date)
        @billing_month = a2_value.month
        @billing_year = a2_value.year
        Rails.logger.info "Found billing date in A2: #{@billing_month}/#{@billing_year}"
        return
      elsif a2_value.is_a?(String) && a2_value =~ /(\d{1,2})[\/\-\.\s](\d{4})/
        # Format MM/YYYY or MM-YYYY
        @billing_month = $1.to_i
        @billing_year = $2.to_i
        Rails.logger.info "Found billing date in A2 (string): #{@billing_month}/#{@billing_year}"
        return
      elsif a2_value.is_a?(String) && a2_value =~ /tháng\s*(\d{1,2})[\/\-\.\s](\d{4})/i
        # Format "Tháng MM/YYYY"
        @billing_month = $1.to_i
        @billing_year = $2.to_i
        Rails.logger.info "Found billing date in A2 (with 'tháng'): #{@billing_month}/#{@billing_year}"
        return
      end
    rescue => e
      Rails.logger.error "Error checking A2: #{e.message}"
    end

    # Then check A1
    begin
      a1_value = sheet.cell(1, 1)
      if a1_value.is_a?(Date)
        @billing_month = a1_value.month
        @billing_year = a1_value.year
        return
      elsif a1_value.is_a?(String) && a1_value =~ /(\d{1,2})[\/\-](\d{4})/
        # Format MM/YYYY or MM-YYYY
        @billing_month = $1.to_i
        @billing_year = $2.to_i
        return
      end
    rescue => e
      Rails.logger.error "Error checking A1: #{e.message}"
    end

    # Check header row for "Tháng X/YYYY" format
    (1..5).each do |row|
      begin
        header_row = sheet.row(row)
        header_row.each_with_index do |cell, index|
          if cell.is_a?(String) && cell.to_s =~ /tháng\s*(\d{1,2})[\/\-](\d{4})/i
            @billing_month = $1.to_i
            @billing_year = $2.to_i
            return
          end
        end
      rescue => e
        Rails.logger.error "Error checking header row #{row}: #{e.message}"
        next
      end
    end

    # Look for date patterns in first several rows
    (1..10).each do |row|
      begin
        current_row = sheet.row(row)
        current_row.each do |cell|
          cell_str = cell.to_s.strip

          # Match date patterns like MM/YYYY, MM-YYYY, or "tháng MM/YYYY"
          if cell_str =~ /(\d{1,2})[\/\-](\d{4})/ || cell_str =~ /tháng\s+(\d{1,2})[\/\-](\d{4})/i
            @billing_month = $1.to_i
            @billing_year = $2.to_i
            return
          end
        end
      rescue => e
        Rails.logger.error "Error checking row #{row}: #{e.message}"
        next
      end
    end
  end

  def map_column_headers(sheet)
    # Headers are in rows 4 and 5 as seen in the image
    headers_row1 = sheet.row(4).map { |h| h.to_s.strip.downcase }
    headers_row2 = sheet.row(5).map { |h| h.to_s.strip.downcase }

    # Log the headers for debugging
    Rails.logger.debug "Headers row 1: #{headers_row1.inspect}"
    Rails.logger.debug "Headers row 2: #{headers_row2.inspect}"

    # Create a mapping of column indices to header names for both rows
    column_headers = {}

    headers_row1.each_with_index do |header, idx|
      column_headers[idx] = {
        main: header.to_s.strip.downcase,
        sub: headers_row2[idx].to_s.strip.downcase
      }
    end

    # Map column indices based on the headers
    @column_indices = {
      room_number: find_column(column_headers, "phòng|room")
    }

    # Find electricity columns (Số điện)
    elec_main_idx = find_column(column_headers, "số điện|điện|electricity")
    if elec_main_idx
      @column_indices[:elec_start] = find_column(column_headers, "số cũ|chỉ số cũ|initial|old", elec_main_idx, elec_main_idx + 3)
      @column_indices[:elec_end] = find_column(column_headers, "số mới|chỉ số mới|final|new", elec_main_idx, elec_main_idx + 3)
    end

    # Find electricity usage (Điện tiêu thụ)
    @column_indices[:elec_usage] = find_column(column_headers, "điện tiêu thụ|tiêu thụ điện|electricity usage")

    # Find water columns (Số nước)
    water_main_idx = find_column(column_headers, "số nước|nước|water")
    if water_main_idx
      @column_indices[:water_start] = find_column(column_headers, "số cũ|chỉ số cũ|initial|old", water_main_idx, water_main_idx + 3)
      @column_indices[:water_end] = find_column(column_headers, "số mới|chỉ số mới|final|new", water_main_idx, water_main_idx + 3)
    end

    # Find water usage (Nước tiêu thụ)
    @column_indices[:water_usage] = find_column(column_headers, "nước tiêu thụ|tiêu thụ nước|water usage")

    # Find tenant name and ID number (CCCD/CMND)
    @column_indices[:tenant_name] = find_column(column_headers, "họ.*tên|tenant|name|người thuê")
    @column_indices[:tenant_phone] = find_column(column_headers, "số điện thoại|phone|sđt|tel|điện thoại")
    @column_indices[:id_number] = find_column(column_headers, "cccd|cmnd|id|căn cước|chứng minh")
    @column_indices[:id_issue_date] = find_column(column_headers, "ngày cấp cccd|ngày cấp|issue date")
    @column_indices[:id_issue_place] = find_column(column_headers, "nơi cấp cccd|nơi cấp|issue place")
    @column_indices[:permanent_address] = find_column(column_headers, "thường trú|địa chỉ thường trú|permanent address")

    # Find first co-tenant information (người ở cùng 1)
    @column_indices[:co_tenant1_name] = find_column(column_headers, "người ở cùng 1|họ.*tên.*cùng 1|co-tenant 1")
    @column_indices[:co_tenant1_phone] = find_column(column_headers, "số điện thoại.*cùng 1|phone.*1|sđt.*1")
    @column_indices[:co_tenant1_id] = find_column(column_headers, "cmnd.*cùng 1|cccd.*cùng 1|id.*co.?tenant.*1")
    @column_indices[:co_tenant1_id_issue_date] = find_column(column_headers, "ngày cấp cccd.*cùng 1|ngày cấp.*cùng 1")
    @column_indices[:co_tenant1_id_issue_place] = find_column(column_headers, "nơi cấp cccd.*cùng 1|nơi cấp.*cùng 1")
    @column_indices[:co_tenant1_permanent_address] = find_column(column_headers, "thường trú.*cùng 1|địa chỉ.*cùng 1")

    # Find second co-tenant information (người ở cùng 2)
    @column_indices[:co_tenant2_name] = find_column(column_headers, "người ở cùng 2|họ.*tên.*cùng 2|co-tenant 2")
    @column_indices[:co_tenant2_phone] = find_column(column_headers, "số điện thoại.*cùng 2|phone.*2|sđt.*2")
    @column_indices[:co_tenant2_id] = find_column(column_headers, "cmnd.*cùng 2|cccd.*cùng 2|id.*co.?tenant.*2")

    # Find vehicle columns (in the circled section from the image)
    @column_indices[:vehicle_plate] = find_column(column_headers, "biển số xe|license plate|plate number")
    @column_indices[:vehicle_plate2] = find_column(column_headers, "biển số xe người ở cùng|co-tenant.*plate|plate.*co-tenant")

    # For backward compatibility - use the first co-tenant as the default co-tenant
    @column_indices[:co_tenant_name] = @column_indices[:co_tenant1_name]
    @column_indices[:co_tenant_phone] = @column_indices[:co_tenant1_phone]
    @column_indices[:co_tenant_id] = @column_indices[:co_tenant1_id]

    # Find other fee columns
    @column_indices[:elec_amount] = find_column(column_headers, "tiền điện|electricity fee")
    @column_indices[:water_amount] = find_column(column_headers, "tiền nước|water fee")
    @column_indices[:room_fee] = find_column(column_headers, "tiền phòng|room fee|rent")
    @column_indices[:service_fee] = find_column(column_headers, "phí dịch vụ|service fee|dịch vụ")
    @column_indices[:wifi_fee] = find_column(column_headers, "mạng|internet|wifi")
    @column_indices[:trash_fee] = find_column(column_headers, "vệ sinh|rác|trash|garbage")

    # Find previous debt and overpayment columns
    @column_indices[:prev_debt] = find_column(column_headers, "nợ cũ|prev.*debt|debt|previous")
    @column_indices[:overpayment] = find_column(column_headers, "thừa|overpayment|excess")

    # Find area column
    @column_indices[:room_area] = find_column(column_headers, "diện tích|area|dt")

    # Find total amount
    @column_indices[:total_amount] = find_column(column_headers, "tổng tiền|tổng cộng|total|total amount|amount")

    # Find payment status
    @column_indices[:payment_status] = find_column(column_headers, "trạng thái|thanh toán|status|payment|paid")

    # Debug log
    Rails.logger.debug "Mapped columns: #{@column_indices.inspect}"
  end

  def find_column(column_headers, search_pattern, start_idx = 0, end_idx = nil)
    end_idx ||= column_headers.keys.max || 0

    column_headers.each do |idx, headers|
      next if idx < start_idx || idx > end_idx

      # Check both main and sub headers
      if headers[:main].to_s.downcase =~ /#{search_pattern}/i ||
         headers[:sub].to_s.downcase =~ /#{search_pattern}/i
        return idx
      end
    end

    nil # Return nil if not found
  end

  def empty_row?(row)
    row.compact.reject(&:blank?).empty?
  end

  def get_cell_value(row, column_key)
    index = @column_indices[column_key]
    return nil if index.nil?
    value = row[index]
    return nil if value.nil? || value.to_s.strip.empty?
    value
  end

  def import_row(row)
    room_number = get_cell_value(row, :room_number).to_s.strip
    return if room_number.blank?

    # Skip header or summary rows that contain these keywords
    invalid_room_patterns = [
      /doanh thu/i, /tổng cộng/i, /tổng số/i, /total/i, /sum/i,
      /phòng số/i, /số phòng/i, /room number/i,
      /^tháng/i, /^month/i, /^ngày/i, /^date/i
    ]

    invalid_room_patterns.each do |pattern|
      if room_number.match?(pattern)
        return # Skip this row as it's likely a header or summary row
      end
    end

    # Room data
    tenant_name = get_cell_value(row, :tenant_name).to_s.strip
    tenant_phone = get_cell_value(row, :tenant_phone).to_s.strip
    tenant_id = get_cell_value(row, :id_number).to_s.strip

    # First co-tenant data
    co_tenant1_name = get_cell_value(row, :co_tenant1_name).to_s.strip
    co_tenant1_phone = get_cell_value(row, :co_tenant1_phone).to_s.strip
    co_tenant1_id = get_cell_value(row, :co_tenant1_id).to_s.strip

    # Second co-tenant data
    co_tenant2_name = get_cell_value(row, :co_tenant2_name).to_s.strip
    co_tenant2_phone = get_cell_value(row, :co_tenant2_phone).to_s.strip
    co_tenant2_id = get_cell_value(row, :co_tenant2_id).to_s.strip

    monthly_rent = get_cell_value(row, :room_fee).to_i
    room_area = get_cell_value(row, :room_area).to_i

    # Kiểm tra xem phòng có dữ liệu nào khác ngoài tên phòng không
    has_other_data = tenant_name.present? ||
                     monthly_rent > 0 ||
                     room_area > 0 ||
                     co_tenant1_name.present? ||
                     co_tenant2_name.present? ||
                     get_cell_value(row, :elec_start).present? ||
                     get_cell_value(row, :elec_end).present? ||
                     get_cell_value(row, :water_start).present? ||
                     get_cell_value(row, :water_end).present?

    # Nếu phòng không có dữ liệu gì ngoài tên, bỏ qua
    unless has_other_data
      Rails.logger.info "Skipping room #{room_number}: No data except room number"
      return
    end

    # Tìm hoặc tạo phòng mới với các thuộc tính hợp lệ - KHÔNG đưa monthly_rent vào
    room = building.rooms.find_by(number: room_number)
    if room.nil?
      # Tạo phòng mới với chỉ các thuộc tính hợp lệ
      room = building.rooms.new(
        number: room_number,
        area: room_area > 0 ? room_area : nil,
        status: tenant_name.present? ? "occupied" : "available"
      )
    else
      # Cập nhật phòng hiện có
      room.area = room_area if room_area > 0
      room.status = tenant_name.present? ? "occupied" : room.status || "available"
    end

    if room.new_record?
      if room.save
        @imported_count[:rooms] += 1
      else
        @errors << "Failed to create room #{room_number}: #{room.errors.full_messages.join(', ')}"
        return
      end
    elsif room.changed?
      # Room exists but had changes
      if room.save
        # We don't increment imported_count for updates
      else
        @errors << "Failed to update room #{room_number}: #{room.errors.full_messages.join(', ')}"
        return
      end
    end

    # Create primary tenant and assignment if name provided
    primary_tenant = nil
    if tenant_name.present?
      primary_tenant = create_tenant_with_details(tenant_name, tenant_phone, tenant_id, room, true, monthly_rent, row) # Mark as representative tenant

      # Process vehicle for primary tenant
      if primary_tenant
        vehicle_plate = get_cell_value(row, :vehicle_plate).to_s.strip
        if vehicle_plate.present?
          create_vehicle(vehicle_plate, primary_tenant)
        end
      end
    end

    # Create first co-tenant if name provided
    co_tenant1 = nil
    if co_tenant1_name.present?
      # Pass the row with co-tenant specific parameters
      co_tenant1 = create_tenant_with_details(co_tenant1_name, co_tenant1_phone, co_tenant1_id, room, false, monthly_rent, row, true, 1) # Not representative tenant, is co-tenant #1

      # Process vehicle for first co-tenant
      if co_tenant1
        vehicle_plate2 = get_cell_value(row, :vehicle_plate2).to_s.strip
        if vehicle_plate2.present?
          create_vehicle(vehicle_plate2, co_tenant1)
        end
      end
    end

    # Create second co-tenant if name provided
    if co_tenant2_name.present?
      # Pass co-tenant #2 specific parameters
      create_tenant_with_details(co_tenant2_name, co_tenant2_phone, co_tenant2_id, room, false, monthly_rent, row, true, 2) # Not representative tenant, is co-tenant #2
    end

    # Create utility readings
    create_utility_readings(row, room)

    # Create bill - associate only with primary tenant
    if primary_tenant
      create_bill(row, room, primary_tenant)
    end
  end

  def is_latest_billing_period?
    return true if @billing_month.nil? || @billing_year.nil? # If we don't have a billing period, assume it's the latest

    # Check if there are any bills with a later date for this building
    current_period = Date.new(@billing_year, @billing_month, 1)

    # Find the latest bill date for this building
    latest_bill = Bill.joins(room_assignment: :room)
                     .where(rooms: { building_id: @building.id })
                     .order(billing_date: :desc)
                     .first

    return true unless latest_bill # No bills exist yet

    # Return true only if current period is greater than or equal to the latest bill date
    current_period >= latest_bill.billing_date
  end

  def create_tenant_with_details(tenant_name, tenant_phone, tenant_id, room, is_representative_tenant = false, monthly_rent = nil, row = nil, is_co_tenant = false, co_tenant_number = nil)
    return nil if tenant_name.blank?

    # Kiểm tra ID number có tồn tại không
    if tenant_id.blank?
      # Bỏ qua tenant không có ID
      Rails.logger.warn "Skipping tenant #{tenant_name} due to missing ID number"
      @errors << "Không thể tạo tenant #{tenant_name} vì thiếu số CMND/CCCD"
      return nil
    end

    # Kiểm tra trong cache trước để cải thiện hiệu suất
    cache_key = "#{tenant_name}-#{tenant_id}"
    if @tenant_cache[cache_key]
      tenant = @tenant_cache[cache_key]
    else
      # Get additional fields for the tenant from Excel
      if defined?(row)
        if is_co_tenant && co_tenant_number
          # Use co-tenant specific column keys
          id_issue_date_key = :"co_tenant#{co_tenant_number}_id_issue_date"
          id_issue_place_key = :"co_tenant#{co_tenant_number}_id_issue_place"
          permanent_address_key = :"co_tenant#{co_tenant_number}_permanent_address"

          id_issue_date_value = get_cell_value(row, id_issue_date_key)
          id_issue_place_value = get_cell_value(row, id_issue_place_key)
          permanent_address_value = get_cell_value(row, permanent_address_key)
        else
          # Use primary tenant column keys
          id_issue_date_value = get_cell_value(row, :id_issue_date)
          id_issue_place_value = get_cell_value(row, :id_issue_place)
          permanent_address_value = get_cell_value(row, :permanent_address)
        end
      else
        id_issue_date_value = nil
        id_issue_place_value = nil
        permanent_address_value = nil
      end

      # Convert id_issue_date to proper date if possible
      parsed_issue_date = nil
      if id_issue_date_value.present?
        begin
          if id_issue_date_value.is_a?(Date)
            parsed_issue_date = id_issue_date_value
          elsif id_issue_date_value.is_a?(String) && id_issue_date_value =~ /(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})/
            # Format DD/MM/YYYY or DD-MM-YYYY
            parsed_issue_date = Date.new($3.to_i, $2.to_i, $1.to_i)
          elsif id_issue_date_value.is_a?(String) && id_issue_date_value =~ /(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})/
            # Format YYYY/MM/DD or YYYY-MM-DD
            parsed_issue_date = Date.new($1.to_i, $2.to_i, $3.to_i)
          end
        rescue => e
          Rails.logger.error "Failed to parse ID issue date '#{id_issue_date_value}': #{e.message}"
        end
      end

      # Tìm kiếm tenant theo id_number
      tenant = Tenant.find_by(id_number: tenant_id)
      if tenant
        Rails.logger.info "Found existing tenant with ID number #{tenant_id}: #{tenant.name}"

        # Cập nhật tên tenant nếu khác với tên hiện tại
        if tenant.name != tenant_name
          Rails.logger.info "Tenant name in Excel (#{tenant_name}) differs from existing tenant name (#{tenant.name}). Using existing tenant."
        end

        # Cập nhật các thông tin khác nếu cần
        tenant_updated = false

        if tenant_phone.present? && tenant.phone.blank?
          tenant.phone = tenant_phone
          tenant_updated = true
          Rails.logger.info "Updated phone number for existing tenant: #{tenant_phone}"
        end

        # Update ID issue date if not already set
        if parsed_issue_date && tenant.id_issue_date.blank?
          tenant.id_issue_date = parsed_issue_date
          tenant_updated = true
          Rails.logger.info "Updated ID issue date for existing tenant: #{parsed_issue_date}"
        end

        # Update ID issue place if not already set
        if id_issue_place_value.present? && tenant.id_issue_place.blank?
          tenant.id_issue_place = id_issue_place_value.to_s.strip
          tenant_updated = true
          Rails.logger.info "Updated ID issue place for existing tenant: #{id_issue_place_value}"
        end

        # Update permanent address if not already set
        if permanent_address_value.present? && tenant.permanent_address.blank?
          tenant.permanent_address = permanent_address_value.to_s.strip
          tenant_updated = true
          Rails.logger.info "Updated permanent address for existing tenant: #{permanent_address_value}"
        end

        # Save if any updates were made
        if tenant_updated
          tenant.save
        end
      else
        # Nếu không tìm thấy theo id_number, tạo mới tenant
        tenant = Tenant.new(
          name: tenant_name,
          phone: tenant_phone.presence || "",
          email: "",
          id_number: tenant_id,
          id_issue_date: parsed_issue_date,
          id_issue_place: id_issue_place_value.to_s.strip.presence,
          permanent_address: permanent_address_value.to_s.strip.presence
        )

        # Kiểm tra xem id_number có bị trùng không
        if Tenant.exists?(id_number: tenant_id)
          @errors << "Trùng số CMND/CCCD #{tenant_id} cho tenant #{tenant_name}. Bỏ qua thêm tenant này."
          Rails.logger.error "Duplicate ID number #{tenant_id} for tenant #{tenant_name}. Skipping."
          return nil
        end

        if tenant.save
          @imported_count[:tenants] += 1
          Rails.logger.info "Successfully created tenant: #{tenant.name} with ID: #{tenant.id_number}"
        else
          @errors << "Failed to create tenant #{tenant_name}: #{tenant.errors.full_messages.join(', ')}"
          Rails.logger.error "Failed to create tenant #{tenant_name}: #{tenant.errors.full_messages.join(', ')}"
          return nil
        end
      end

      # Lưu vào cache để tái sử dụng
      @tenant_cache[cache_key] = tenant
    end

    # Kiểm tra xem đã có representative tenant cho phòng này chưa nếu tenant này được đánh dấu là representative
    if is_representative_tenant
      existing_rep = RoomAssignment.where(room: room, active: true, is_representative_tenant: true).first
      if existing_rep && existing_rep.tenant_id != tenant.id
        Rails.logger.warn "Room #{room.number} already has a representative tenant. Setting #{tenant.name} as a regular tenant."
        is_representative_tenant = false
      end
    end

    # Kiểm tra xem kỳ hóa đơn hiện tại có phải là kỳ mới nhất không
    is_latest_period = is_latest_billing_period?

    # Nếu không phải kỳ mới nhất, ghi log
    unless is_latest_period
      Rails.logger.info "Current billing period #{@billing_month}/#{@billing_year} is not the latest period. Room prices will not be updated except for new tenants."
    end

    # Kiểm tra xem tenant đã từng được assign vào phòng này trước đó chưa (kể cả inactive)
    # Commented out because not currently used:
    # previous_assignment = RoomAssignment.where(room: room, tenant: tenant).order(start_date: :desc).first

    # Create room assignment if not exists
    unless RoomAssignment.exists?(room: room, tenant: tenant, active: true)
      # Set rent amount only if we are in the latest billing period or this is a new tenant (don't have assignment yet)
      assignment_monthly_rent = nil
      assignment_deposit = nil

      # Kiểm tra xem có phải là tenant mới không (chưa có room assignment) hoặc kỳ hóa đơn hiện tại
      # là kỳ mới nhất. Nếu đúng, cập nhật giá phòng.
      if is_representative_tenant
        if is_latest_period || !RoomAssignment.exists?(tenant: tenant)
          assignment_monthly_rent = monthly_rent
          assignment_deposit = monthly_rent
        end
      end

      # Luôn sử dụng ngày bắt đầu từ dữ liệu import - không sử dụng lại ngày cũ
      start_date = Date.new(@billing_year, @billing_month, 1)

      assignment = RoomAssignment.new(
        room: room,
        tenant: tenant,
        start_date: start_date,
        active: true,
        is_representative_tenant: is_representative_tenant,
        monthly_rent: assignment_monthly_rent,
        deposit_amount: assignment_deposit
      )

      if assignment.save
        Rails.logger.info "Successfully created room assignment for #{tenant.name} in room #{room.number}" +
                        (is_representative_tenant ? " (Representative)" : "") +
                        (is_representative_tenant && assignment_monthly_rent ? " with monthly rent: #{assignment_monthly_rent}" : "") +
                        (is_representative_tenant && assignment_deposit ? " and deposit: #{assignment_deposit}" : "")
      else
        @errors << "Failed to assign tenant to room: #{assignment.errors.full_messages.join(', ')}"
        Rails.logger.error "Failed to assign tenant to room: #{assignment.errors.full_messages.join(', ')}"
      end
    else
      # Update existing assignment if needed
      existing_assignment = RoomAssignment.where(room: room, tenant: tenant, active: true).first

      # Cập nhật start_date từ file Excel nếu start_date mới cũ hơn start_date hiện tại
      # Mục đích: Đảm bảo start_date luôn là ngày sớm nhất mà tenant thuê phòng
      import_date = Date.new(@billing_year, @billing_month, 1)
      if import_date < existing_assignment.start_date
        existing_assignment.start_date = import_date
        Rails.logger.info "Updating start_date for #{tenant.name} in room #{room.number} from #{existing_assignment.start_date} to #{import_date}"
      end

      # Cập nhật giá phòng và tiền cọc chỉ khi là representative tenant
      # VÀ kỳ hóa đơn hiện tại là kỳ mới nhất
      if is_representative_tenant && is_latest_period
        if monthly_rent.present? && existing_assignment.monthly_rent != monthly_rent
          existing_assignment.monthly_rent = monthly_rent
          # Cập nhật cả tiền cọc nếu chưa có hoặc khi tiền thuê thay đổi
          if existing_assignment.deposit_amount.blank? || existing_assignment.deposit_amount != monthly_rent
            existing_assignment.deposit_amount = monthly_rent
            Rails.logger.info "Updating monthly rent and deposit for #{tenant.name} in room #{room.number} to #{monthly_rent}"
          else
            Rails.logger.info "Updating monthly rent for #{tenant.name} in room #{room.number} to #{monthly_rent}"
          end
        end
      elsif !is_representative_tenant && (existing_assignment.monthly_rent.present? || existing_assignment.deposit_amount.present?)
        # Nếu không phải representative tenant, đặt monthly_rent và deposit_amount về nil
        if is_latest_period
          existing_assignment.monthly_rent = nil
          existing_assignment.deposit_amount = nil
          Rails.logger.info "Removing monthly rent and deposit for non-representative tenant #{tenant.name} in room #{room.number}"
        end
      end

      if existing_assignment && is_representative_tenant && !existing_assignment.is_representative_tenant
        existing_assignment.is_representative_tenant = true

        # Nếu tenant được nâng cấp thành representative VÀ kỳ hóa đơn hiện tại là kỳ mới nhất,
        # đặt monthly_rent và deposit_amount
        if monthly_rent.present? && is_latest_period
          existing_assignment.monthly_rent = monthly_rent
          existing_assignment.deposit_amount = monthly_rent
          Rails.logger.info "Setting #{tenant.name} as representative with rent/deposit of #{monthly_rent}"
        end
      end

      if existing_assignment.changed?
        if existing_assignment.save
          Rails.logger.info "Updated room assignment for #{tenant.name} in room #{room.number}"
        else
          @errors << "Failed to update room assignment: #{existing_assignment.errors.full_messages.join(', ')}"
        end
      end
    end

    tenant
  end

  def create_utility_readings(row, room)
    # Make sure we have valid billing month and year before proceeding
    unless @billing_month.present? && @billing_year.present? &&
            @billing_month.between?(1, 12) && @billing_year.between?(2000, 2100)
      Rails.logger.error "Invalid billing period: #{@billing_month}/#{@billing_year}"
      @errors << "Invalid billing period: #{@billing_month}/#{@billing_year}"
      return
    end

    begin
      billing_date = Date.new(@billing_year, @billing_month, 1)
      # Calculate the previous month's date for storing old readings
      previous_month_date = billing_date - 1.month
      Rails.logger.info "Creating utility readings for room #{room.number} with date #{billing_date}"
    rescue ArgumentError => e
      @errors << "Invalid billing date: #{@billing_month}/#{@billing_year}. Error: #{e.message}"
      return
    end

    # Electricity reading
    elec_start = get_cell_value(row, :elec_start).to_i
    elec_end = get_cell_value(row, :elec_end).to_i

    Rails.logger.info "Electricity readings: #{elec_start} → #{elec_end}"

    # If elec_start or elec_end is missing, try to get from elec_usage column
    if (!elec_start || !elec_end || elec_start == 0 || elec_end == 0) && @column_indices[:elec_usage]
      elec_usage_text = get_cell_value(row, :elec_usage).to_s
      Rails.logger.info "Trying to extract electricity from usage text: #{elec_usage_text}"
      # Try to extract start and end values if they're in format "start → end" or "start - end"
      if elec_usage_text =~ /(\d+)(?:\s*(?:→|-|to)\s*)(\d+)/
        elec_start = $1.to_i
        elec_end = $2.to_i
        Rails.logger.info "Extracted electricity: #{elec_start} → #{elec_end}"
      end
    end

    # Water reading
    water_start = get_cell_value(row, :water_start).to_i
    water_end = get_cell_value(row, :water_end).to_i

    Rails.logger.info "Water readings: #{water_start} → #{water_end}"

    # If water_start or water_end is missing, try to get from water_usage column
    if (!water_start || !water_end || water_start == 0 || water_end == 0) && @column_indices[:water_usage]
      water_usage_text = get_cell_value(row, :water_usage).to_s
      Rails.logger.info "Trying to extract water from usage text: #{water_usage_text}"
      # Try to extract start and end values if they're in format "start → end" or "start - end"
      if water_usage_text =~ /(\d+)(?:\s*(?:→|-|to)\s*)(\d+)/
        water_start = $1.to_i
        water_end = $2.to_i
        Rails.logger.info "Extracted water: #{water_start} → #{water_end}"
      end
    end

    # Save previous readings (start values) to the previous month
    if elec_start && elec_start >= 0
      begin
        # Find or create reading for the previous month
        prev_reading = UtilityReading.find_or_initialize_by(
          room_id: room.id,
          reading_date: previous_month_date
        )

        # Set the previous month's reading to the start value
        prev_reading.electricity_reading = elec_start

        if prev_reading.save
          @imported_count[:utility_readings] += 1 if prev_reading.previous_changes.any?
          Rails.logger.info "Successfully saved previous electricity reading: #{elec_start} for date: #{previous_month_date}"
        else
          @errors << "Failed to create previous utility reading for room #{room.number}: #{prev_reading.errors.full_messages.join(', ')}"
          Rails.logger.error "Failed to save previous utility reading: #{prev_reading.errors.full_messages.join(', ')}"
        end
      rescue => e
        @errors << "Error creating previous utility reading: #{e.message}"
        Rails.logger.error "Exception creating previous utility reading: #{e.message}"
      end
    end

    # Save previous water readings to the previous month
    if water_start && water_start >= 0
      begin
        # Find or update the same previous month reading record we created above
        prev_reading = UtilityReading.find_or_initialize_by(
          room_id: room.id,
          reading_date: previous_month_date
        )

        # Update with water start value
        prev_reading.water_reading = water_start

        if prev_reading.save
          Rails.logger.info "Successfully saved previous water reading: #{water_start} for date: #{previous_month_date}"
        else
          @errors << "Failed to update previous water reading for room #{room.number}: #{prev_reading.errors.full_messages.join(', ')}"
          Rails.logger.error "Failed to save previous water reading: #{prev_reading.errors.full_messages.join(', ')}"
        end
      rescue => e
        @errors << "Error updating previous water reading: #{e.message}"
        Rails.logger.error "Exception updating previous water reading: #{e.message}"
      end
    end

    # Save current readings (end values) to the current month
    if elec_end && elec_end >= 0
      begin
        # Find existing reading or create a new one
        reading = UtilityReading.find_or_initialize_by(
          room_id: room.id,
          reading_date: billing_date
        )

        # Update both new and existing readings
        reading.electricity_reading = elec_end

        if reading.save
          @imported_count[:utility_readings] += 1 if reading.previous_changes.any?
          Rails.logger.info "Successfully saved electricity reading: #{elec_end} (previous: #{elec_start})"
        else
          @errors << "Failed to create utility reading for room #{room.number}: #{reading.errors.full_messages.join(', ')}"
          Rails.logger.error "Failed to save utility reading: #{reading.errors.full_messages.join(', ')}"
        end
      rescue => e
        @errors << "Error creating utility reading: #{e.message}"
        Rails.logger.error "Exception creating utility reading: #{e.message}"
      end
    else
      Rails.logger.warn "Invalid electricity readings: #{elec_start} → #{elec_end}"
    end

    # Current month water readings
    if water_end && water_end >= 0
      begin
        # Find the reading we just created or updated above, or create a new one if it doesn't exist
        reading = UtilityReading.find_or_initialize_by(
          room_id: room.id,
          reading_date: billing_date
        )

        # Update water reading
        reading.water_reading = water_end

        if reading.save
          @imported_count[:utility_readings] += 1 if reading.previous_changes.any?
          Rails.logger.info "Successfully saved water reading: #{water_end} (previous: #{water_start})"
        else
          @errors << "Failed to update water reading for room #{room.number}: #{reading.errors.full_messages.join(', ')}"
          Rails.logger.error "Failed to save water reading: #{reading.errors.full_messages.join(', ')}"
        end
      rescue => e
        @errors << "Error updating water reading: #{e.message}"
        Rails.logger.error "Exception updating water reading: #{e.message}"
      end
    else
      Rails.logger.warn "Invalid water readings: #{water_start} → #{water_end}"
    end
  end

  def create_bill(row, room, tenant = nil)
    unless @billing_month.present? && @billing_year.present? &&
            @billing_month.between?(1, 12) && @billing_year.between?(2000, 2100)
      Rails.logger.error "Invalid billing period for bill: #{@billing_month}/#{@billing_year}"
      return
    end

    begin
      billing_date = Date.new(@billing_year, @billing_month, 1)
      due_date = billing_date + 10.days  # Due 10 days after billing date
      Rails.logger.info "Creating bill for room #{room.number} with date #{billing_date}"
    rescue ArgumentError => e
      @errors << "Invalid billing date: #{@billing_month}/#{@billing_year}. Error: #{e.message}"
      return
    end

    # Get values for bill
    room_fee = get_cell_value(row, :room_fee).to_i
    elec_amount = get_cell_value(row, :elec_amount).to_i
    water_amount = get_cell_value(row, :water_amount).to_i

    # Log water fee details for debugging
    Rails.logger.info "Water fee from Excel: #{water_amount}"

    # Make sure water_amount is not set to 0 when there's an actual value in the Excel
    if water_amount == 0 && @column_indices[:water_amount]
      water_amount_direct = row[@column_indices[:water_amount]].to_i
      Rails.logger.info "Attempting to get water fee directly from column: #{water_amount_direct}"
      water_amount = water_amount_direct if water_amount_direct > 0
    end

    # As a fallback, try to calculate water fee from readings if available
    if water_amount == 0
      begin
        water_start = get_cell_value(row, :water_start).to_i
        water_end = get_cell_value(row, :water_end).to_i
        water_usage = water_end - water_start

        # Try to get price from the utility price model
        latest_price = UtilityPrice.where(building: @building)
                                  .where("effective_date <= ?", billing_date)
                                  .order(effective_date: :desc)
                                  .first

        # Nếu không có giá cụ thể cho tòa nhà, dùng giá chung
        if latest_price.nil?
          latest_price = UtilityPrice.where(building_id: nil)
                                   .where("effective_date <= ?", billing_date)
                                   .order(effective_date: :desc)
                                   .first
        end

        if latest_price && latest_price.water_unit_price > 0 && water_usage > 0
          calculated_water_fee = water_usage * latest_price.water_unit_price
          Rails.logger.info "Calculated water fee from readings: #{calculated_water_fee} (usage: #{water_usage} * price: #{latest_price.water_unit_price})"
          water_amount = calculated_water_fee
        end
      rescue => e
        Rails.logger.error "Error calculating water fee from readings: #{e.message}"
      end
    end

    # Get service fee - this will be saved to the dedicated service_fee column
    service_fee = get_cell_value(row, :service_fee).to_i
    Rails.logger.info "Service fee from Excel: #{service_fee}"

    # Get previous debt and overpayment values
    prev_debt = get_cell_value(row, :prev_debt).to_i
    overpayment = get_cell_value(row, :overpayment).to_i

    Rails.logger.info "Previous debt: #{prev_debt}, Overpayment: #{overpayment}"

    total_amount = get_cell_value(row, :total_amount).to_i
    payment_status = get_cell_value(row, :payment_status).to_s.strip.downcase

    Rails.logger.info "Bill values: room_fee=#{room_fee}, elec=#{elec_amount}, water=#{water_amount}, service=#{service_fee}, prev_debt=#{prev_debt}, overpayment=#{overpayment}, total=#{total_amount}"

    # Use provided tenant or find current tenant for bill
    unless tenant
      tenant = room.current_tenant
      unless tenant
        @errors << "No active tenant found for room #{room.number}. Bill cannot be created."
        Rails.logger.error "No active tenant found for room #{room.number}. Bill cannot be created."
        return
      end
    end

    Rails.logger.info "Creating bill for tenant: #{tenant.name}"

    # Find the active room assignment between tenant and room
    room_assignment = RoomAssignment.where(room: room, tenant: tenant, active: true).first

    unless room_assignment
      @errors << "No active room assignment found for tenant #{tenant.name} in room #{room.number}. Bill cannot be created."
      Rails.logger.error "No active room assignment found for tenant #{tenant.name} in room #{room.number}. Bill cannot be created."
      return
    end

    # Now use room_assignment_id instead of room_id and match by billing_date instead of period start/end
    begin
      # Find existing bill by room_assignment and billing_date
      bill = Bill.where(
        room_assignment_id: room_assignment.id,
        billing_date: billing_date
      ).first

      # If no bill found, create new one
      if bill.nil?
        bill = Bill.new(
          room_assignment: room_assignment,
          billing_date: billing_date,
          due_date: due_date
        )
        bill_is_new = true
      else
        bill_is_new = false
      end

      # Update bill attributes
      bill.room_fee = room_fee if room_fee > 0
      bill.electricity_fee = elec_amount if elec_amount > 0
      bill.water_fee = water_amount if water_amount > 0
      bill.service_fee = service_fee if service_fee > 0

      # Lưu nợ cũ và thừa vào các cột riêng biệt thay vì other_fees
      bill.previous_debt = prev_debt if prev_debt > 0
      bill.overpayment = overpayment if overpayment > 0

      # Đặt other_fees về 0 vì giờ đã có cột riêng cho nợ cũ và thừa
      bill.other_fees = 0

      # Calculate total if not provided
      if total_amount > 0
        bill.total_amount = total_amount
      else
        # Let the model calculate the total based on individual fees
        bill.calculate_total if bill.respond_to?(:calculate_total)
      end

      # Set status based on payment status field (if exists)
      if payment_status.present?
        if payment_status.include?("đã thanh toán") || payment_status.include?("paid")
          bill.status = "paid"
        else
          bill.status = "unpaid"
        end
      else
        bill.status = "unpaid"
      end

      # Set notes with breakdown of fees
      notes = []
      notes << "Room Fee: #{room_fee}" if room_fee > 0
      notes << "Electricity: #{elec_amount}" if elec_amount > 0
      notes << "Water: #{water_amount}" if water_amount > 0
      notes << "Service Fee: #{service_fee}" if service_fee && service_fee > 0
      notes << "Previous Debt: #{prev_debt}" if prev_debt && prev_debt > 0
      notes << "Overpayment Credit: #{overpayment}" if overpayment && overpayment > 0
      bill.notes = notes.join(", ")

      if bill.save
        if bill_is_new
          @imported_count[:bills] += 1
          Rails.logger.info "Successfully created bill: #{bill.id}"
        else
          Rails.logger.info "Successfully updated bill: #{bill.id}"
        end
      else
        @errors << "Failed to create bill for room #{room.number}: #{bill.errors.full_messages.join(', ')}"
        Rails.logger.error "Failed to save bill: #{bill.errors.full_messages.join(', ')}"
      end
    rescue => e
      @errors << "Error creating bill: #{e.message}"
      Rails.logger.error "Exception when creating bill: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    end
  end

  def create_vehicle(plate_number, tenant)
    return if plate_number.blank? || tenant.nil?

    # Extract vehicle model and color if present in parentheses
    model = nil
    color = nil

    # Extract content from parentheses if present (e.g. "59F1-12345 (Wave Blue)")
    if plate_number.include?("(") && plate_number.include?(")")
      parentheses_content = plate_number.match(/\((.*?)\)/)[1].to_s.strip
      plate_number = plate_number.gsub(/\s*\(.*?\)\s*/, "").strip

      # Parse parentheses content - first word is model, second word is color
      if parentheses_content.present?
        parts = parentheses_content.split(" ", 2)
        model = parts[0] if parts[0].present?
        color = parts[1] if parts.length > 1 && parts[1].present?

        Rails.logger.info "Extracted from license plate: Model=#{model}, Color=#{color}"
      end
    end

    plate_number = plate_number.strip.upcase

    # Check if the vehicle with this plate already exists
    existing_vehicle = Vehicle.find_by(license_plate: plate_number)

    if existing_vehicle
      # If the vehicle exists but belongs to a different tenant, log a warning
      if existing_vehicle.tenant_id != tenant.id
        @errors << "Vehicle with plate #{plate_number} already registered to a different tenant."
        Rails.logger.warn "Vehicle with plate #{plate_number} already registered to tenant #{existing_vehicle.tenant_id}, not adding to tenant #{tenant.id}"
        return
      else
        # Vehicle already exists for this tenant, update model and color if provided
        if model.present? || color.present?
          existing_vehicle.model = model if model.present? && existing_vehicle.model.blank?
          existing_vehicle.color = color if color.present? && existing_vehicle.color.blank?

          if existing_vehicle.changed?
            if existing_vehicle.save
              Rails.logger.info "Updated vehicle #{plate_number} with model: #{model}, color: #{color}"
            else
              @errors << "Failed to update vehicle details: #{existing_vehicle.errors.full_messages.join(', ')}"
            end
          end
        end

        Rails.logger.info "Vehicle with plate #{plate_number} already registered to tenant #{tenant.name}"
        return
      end
    end

    # Determine vehicle type based on plate format
    vehicle_type = "motorcycle"

    # Create the new vehicle
    vehicle = Vehicle.new(
      tenant: tenant,
      license_plate: plate_number,
      vehicle_type: vehicle_type,
      model: model,
      color: color,
      notes: "Imported from Excel"
    )

    if vehicle.save
      @imported_count[:vehicles] += 1
      Rails.logger.info "Successfully registered vehicle #{plate_number} for tenant #{tenant.name}, model: #{model}, color: #{color}"
    else
      @errors << "Failed to register vehicle #{plate_number}: #{vehicle.errors.full_messages.join(', ')}"
      Rails.logger.error "Failed to register vehicle #{plate_number}: #{vehicle.errors.full_messages.join(', ')}"
    end
  end
end
