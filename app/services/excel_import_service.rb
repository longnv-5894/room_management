class ExcelImportService
  attr_reader :file_path, :building, :errors, :imported_count, :billing_month, :billing_year

  def initialize(file_path, building)
    @file_path = file_path
    @building = building
    @errors = []
    @imported_count = { rooms: 0, tenants: 0, utility_readings: 0, bills: 0, expenses: 0, utility_prices: 0 }
    @billing_month = nil
    @billing_year = nil
    @column_indices = {}
  end
  
  def import
    return false unless valid_file?
    
    begin
      ActiveRecord::Base.transaction do
        spreadsheet = Roo::Spreadsheet.open(file_path)
        
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
      puts "Exception details: #{e.backtrace.join("\n")}" # For debugging
      false
    end
  end
  
  private
  
  def process_room_data(sheet)
    # Map the column headers to indices - headers are in rows 4 and 5
    map_column_headers(sheet)
    
    # Extract billing month/year from sheet data
    extract_billing_period_from_data(sheet)
    
    # Start from row 6 (after header rows)
    ((sheet.first_row + 5)..sheet.last_row).each do |row_index|
      row = sheet.row(row_index)
      import_row(row) unless empty_row?(row)
    end
  end
  
  def process_operating_expenses(sheet)
    puts "Processing operating expenses sheet"
    
    # Find the expense categories and amounts columns
    expense_category_col = nil
    expense_amount_col = nil
    
    # Look through the first few rows to identify the column headers
    (1..10).each do |row_idx|
      row = sheet.row(row_idx)
      next if empty_row?(row)
      
      row.each_with_index do |cell, col_idx|
        cell_text = cell.to_s.strip.downcase
        if cell_text.include?("khoản chi") || cell_text.include?("expense")
          expense_category_col = col_idx
        elsif cell_text.include?("số tiền") || cell_text.include?("amount")
          expense_amount_col = col_idx
        end
      end
      
      break if expense_category_col && expense_amount_col
    end
    
    return if expense_category_col.nil? || expense_amount_col.nil?
    
    # Define the starting row after headers
    start_row = nil
    (expense_category_col ? 1 : 1).upto(sheet.last_row) do |row_idx|
      row = sheet.row(row_idx)
      cell_value = row[expense_category_col].to_s.strip.downcase if row[expense_category_col]
      if cell_value && (cell_value.include?('tiền') || cell_value.match(/^[a-z]+ cost$/i))
        start_row = row_idx
        break
      end
    end
    
    return if start_row.nil?
    
    # Process expense rows
    start_row.upto(sheet.last_row) do |row_idx|
      row = sheet.row(row_idx)
      next if empty_row?(row)
      
      category = row[expense_category_col].to_s.strip
      amount = row[expense_amount_col].to_f
      
      # Skip total rows or empty categories
      next if category.blank? || category.downcase.include?('tổng') || category.downcase.include?('total')
      next if amount <= 0
      
      # Map category to system category
      expense_category = map_expense_category(category)
      
      puts "Found expense: #{category} => #{expense_category} - #{amount}"
      
      # Create operating expense
      expense = OperatingExpense.new(
        building: @building,
        category: expense_category,
        amount: amount,
        expense_date: Date.new(@billing_year || Date.today.year, @billing_month || Date.today.month, 1),
        description: category
      )
      
      if expense.save
        @imported_count[:expenses] += 1
        puts "Successfully created operating expense: #{expense.category} - #{expense.amount}"
      else
        @errors << "Failed to create operating expense #{category}: #{expense.errors.full_messages.join(', ')}"
        puts "Failed to create operating expense: #{expense.errors.full_messages.join(', ')}"
      end
    end
  end
  
  def map_expense_category(category)
    category = category.to_s.strip.downcase
    
    mapping = {
      /tiền điện|electricity|electric/i => 'electric',
      /tiền nước|water/i => 'water',
      /tiền mạng|internet|wifi/i => 'internet',
      /tiền vệ sinh|clean/i => 'cleaning',
      /tiền rác|garbage|trash/i => 'miscellaneous',
      /sửa chữa|repair/i => 'repairs',
      /bảo trì|maintenance/i => 'maintenance',
      /an ninh|security/i => 'security',
      /bảo hiểm|insurance/i => 'insurance',
      /thuế|tax/i => 'taxes',
      /lương|salary/i => 'staff_salary',
      /thầu|rent/i => 'rent'
    }
    
    mapping.each do |pattern, mapped_category|
      return mapped_category if category.match?(pattern)
    end
    
    'miscellaneous' # Default category
  end
  
  def process_utility_prices(sheet)
    puts "Processing utility prices sheet"
    
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
        
        if cell_text.include?('tiền điện') || cell_text.include?('electricity')
          # Look for the rate value in the next column
          rate_value = row[col_idx + 1].to_f if row[col_idx + 1]
          electricity_rate = rate_value if rate_value && rate_value > 0
        elsif cell_text.include?('tiền nước') || cell_text.include?('water')
          rate_value = row[col_idx + 1].to_f if row[col_idx + 1]
          water_rate = rate_value if rate_value && rate_value > 0
        elsif cell_text.include?('phí dịch vụ') || cell_text.include?('service')
          rate_value = row[col_idx + 1].to_f if row[col_idx + 1]
          service_fee = rate_value if rate_value && rate_value > 0
        end
      end
    end
    
    if water_rate || service_fee
      puts "Found utility prices - Electricity: #{electricity_rate}, Water: #{water_rate}, Service: #{service_fee}"
      
      # Create a new utility price record
      # Set default electricity unit price if not provided to avoid validation errors
      utility_price = UtilityPrice.new(
        electricity_unit_price: electricity_rate || 0,  # Default to 0 if nil
        water_unit_price: water_rate || 0,             # Default to 0 if nil
        service_charge: service_fee || 0,              # Default to 0 if nil
        effective_date: Date.new(@billing_year || Date.today.year, @billing_month || Date.today.month, 1),
        notes: "Imported from Excel file for #{@billing_month}/#{@billing_year}"
      )
      
      if utility_price.save
        @imported_count[:utility_prices] += 1
        puts "Successfully created utility price settings"
      else
        @errors << "Failed to create utility price settings: #{utility_price.errors.full_messages.join(', ')}"
        puts "Failed to create utility price settings: #{utility_price.errors.full_messages.join(', ')}"
      end
    end
  end

  def valid_file?
    unless File.exist?(file_path)
      @errors << "File not found: #{file_path}"
      return false
    end
    
    extension = File.extname(file_path).downcase
    unless ['.xlsx', '.xls'].include?(extension)
      @errors << "Invalid file format. Please upload an Excel file (.xlsx or .xls)"
      return false
    end
    
    true
  end
  
  def extract_billing_period_from_data(sheet)
    # Default to current date
    current_date = Date.today
    @billing_month = current_date.month
    @billing_year = current_date.year
    
    # First check A2, which often contains date information in your excel format
    begin
      a2_value = sheet.cell(2, 1)
      if a2_value.is_a?(Date)
        @billing_month = a2_value.month
        @billing_year = a2_value.year
        puts "Found billing date in A2: #{@billing_month}/#{@billing_year}"
        return
      elsif a2_value.is_a?(String) && a2_value =~ /(\d{1,2})[\/\-\.\s](\d{4})/
        # Format MM/YYYY or MM-YYYY
        @billing_month = $1.to_i
        @billing_year = $2.to_i
        puts "Found billing date in A2 (string): #{@billing_month}/#{@billing_year}"
        return
      elsif a2_value.is_a?(String) && a2_value =~ /tháng\s*(\d{1,2})[\/\-\.\s](\d{4})/i
        # Format "Tháng MM/YYYY"
        @billing_month = $1.to_i
        @billing_year = $2.to_i
        puts "Found billing date in A2 (with 'tháng'): #{@billing_month}/#{@billing_year}"
        return
      end
    rescue => e
      puts "Error checking A2: #{e.message}"
      # Continue if A2 doesn't work
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
    rescue
      # Continue if A1 doesn't work
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
      rescue
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
      rescue
        next
      end
    end
  end
  
  def map_column_headers(sheet)
    # Headers are in rows 4 and 5 as seen in the image
    headers_row1 = sheet.row(4).map(&:to_s)
    headers_row2 = sheet.row(5).map(&:to_s)
    
    # Create a mapping of column indices to header names for both rows
    column_headers = {}
    
    headers_row1.each_with_index do |header, idx|
      column_headers[idx] = { 
        main: header.to_s.strip,
        sub: headers_row2[idx].to_s.strip
      }
    end
    
    # Map column indices based on the headers
    @column_indices = {
      room_number: find_column(column_headers, 'phòng')
    }
    
    # Find electricity columns (Số điện)
    elec_main_idx = find_column(column_headers, 'số điện')
    if elec_main_idx
      @column_indices[:elec_start] = find_column(column_headers, 'số cũ', elec_main_idx, elec_main_idx + 3)
      @column_indices[:elec_end] = find_column(column_headers, 'số mới', elec_main_idx, elec_main_idx + 3)
    end
    
    # Find electricity usage (Điện tiêu thụ)
    @column_indices[:elec_usage] = find_column(column_headers, 'điện tiêu thụ')
    
    # Find water columns (Số nước)
    water_main_idx = find_column(column_headers, 'số nước')
    if water_main_idx
      @column_indices[:water_start] = find_column(column_headers, 'số cũ', water_main_idx, water_main_idx + 3)
      @column_indices[:water_end] = find_column(column_headers, 'số mới', water_main_idx, water_main_idx + 3)
    end
    
    # Find water usage (Nước tiêu thụ)
    @column_indices[:water_usage] = find_column(column_headers, 'nước tiêu thụ')
    
    # Find tenant name and ID number (CCCD/CMND)
    @column_indices[:tenant_name] = find_column(column_headers, 'họ.*tên')
    @column_indices[:tenant_phone] = find_column(column_headers, 'số điện thoại')
    @column_indices[:id_number] = find_column(column_headers, 'cccd|cmnd')
    
    # Find co-tenant information
    @column_indices[:co_tenant_name] = find_column(column_headers, 'người ở cùng|họ.*tên.*cùng')
    @column_indices[:co_tenant_phone] = find_column(column_headers, 'số điện thoại.*cùng')
    @column_indices[:co_tenant_id] = find_column(column_headers, 'cccd|cmnd.*cùng')
    
    # Find other fee columns
    @column_indices[:elec_amount] = find_column(column_headers, 'tiền điện')
    @column_indices[:water_amount] = find_column(column_headers, 'tiền nước')
    @column_indices[:room_fee] = find_column(column_headers, 'tiền phòng')
    @column_indices[:service_fee] = find_column(column_headers, 'phí dịch vụ')
    @column_indices[:wifi_fee] = find_column(column_headers, 'mạng|internet')
    @column_indices[:trash_fee] = find_column(column_headers, 'vệ sinh|rác')
    
    # Find area column
    @column_indices[:room_area] = find_column(column_headers, 'diện tích')
    
    # Find total amount
    @column_indices[:total_amount] = find_column(column_headers, 'tổng tiền|tổng cộng')
    
    # Find payment status
    @column_indices[:payment_status] = find_column(column_headers, 'trạng thái|thanh toán')
    
    # Debug log
    puts "Mapped columns: #{@column_indices.inspect}"
  end
  
  def find_column(column_headers, search_pattern, start_idx = 0, end_idx = nil)
    end_idx ||= column_headers.keys.max
    
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
    
    # Co-tenant data
    co_tenant_name = get_cell_value(row, :co_tenant_name).to_s.strip
    co_tenant_phone = get_cell_value(row, :co_tenant_phone).to_s.strip
    co_tenant_id = get_cell_value(row, :co_tenant_id).to_s.strip
    
    monthly_rent = get_cell_value(row, :room_fee).to_f
    room_area = get_cell_value(row, :room_area).to_f
    
    # Skip importing rooms without a specified monthly rent
    if monthly_rent <= 0
      # Không thêm vào @errors để tránh rollback toàn bộ transaction
      puts "Skipping room #{room_number}: No valid monthly rent specified"
      return
    end
    
    # Get or create room
    room = building.rooms.find_or_initialize_by(number: room_number)
    
    # Check if existing room has empty status and skip if so
    if !room.new_record? && room.status.blank?
      puts "Skipping room #{room_number} with empty status"
      return
    end
    
    # Update room attributes for both new and existing rooms
    room.monthly_rent = monthly_rent
    room.area = room_area if room_area > 0
    room.status = tenant_name.present? ? 'occupied' : room.status || 'available'
    
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
      primary_tenant = create_tenant_with_details(tenant_name, tenant_phone, tenant_id, room)
    end
    
    # Create co-tenant and assignment if name provided
    co_tenant = nil
    if co_tenant_name.present?
      co_tenant = create_tenant_with_details(co_tenant_name, co_tenant_phone, co_tenant_id, room)
      create_room_assignment(co_tenant, room) if co_tenant
    end
    
    # Create utility readings
    create_utility_readings(row, room)
    
    # Create bill - associate only with primary tenant
    if primary_tenant
      create_bill(row, room, primary_tenant)
    end
  end
  
  def create_tenant_with_details(tenant_name, tenant_phone, tenant_id, room)
    return nil if tenant_name.blank?
    
    # Nếu không tìm thấy ID trong excel, tạo một ID tạm thời
    if tenant_id.blank?
      # Tạo ID từ tên + phòng để đảm bảo duy nhất
      tenant_id = "ID-#{tenant_name.parameterize}-#{room.number.parameterize}-#{SecureRandom.hex(3)}"
      puts "No ID number found for tenant #{tenant_name}, generated: #{tenant_id}"
    else
      puts "Found ID number for tenant #{tenant_name}: #{tenant_id}"
    end
    
    # Tìm kiếm tenant theo id_number trước nếu có
    existing_tenant_by_id = nil
    if tenant_id.present? && tenant_id !~ /^ID-/  # Không tìm kiếm nếu là ID tạm thời
      existing_tenant_by_id = Tenant.find_by(id_number: tenant_id)
      if existing_tenant_by_id
        puts "Found existing tenant with ID number #{tenant_id}: #{existing_tenant_by_id.name}"
        
        # Cập nhật tên tenant nếu khác với tên hiện tại
        if existing_tenant_by_id.name != tenant_name
          puts "Tenant name in Excel (#{tenant_name}) differs from existing tenant name (#{existing_tenant_by_id.name}). Using existing tenant."
        end
        
        # Cập nhật số điện thoại nếu cần
        if tenant_phone.present? && existing_tenant_by_id.phone.blank?
          existing_tenant_by_id.phone = tenant_phone
          existing_tenant_by_id.save
          puts "Updated phone number for existing tenant: #{tenant_phone}"
        end
        
        # Tạo room assignment cho tenant đã tồn tại
        unless RoomAssignment.exists?(room: room, tenant: existing_tenant_by_id, active: true)
          assignment = RoomAssignment.new(
            room: room,
            tenant: existing_tenant_by_id,
            start_date: Date.new(@billing_year, @billing_month, 1),
            active: true
          )
          
          if assignment.save
            puts "Successfully created room assignment for #{existing_tenant_by_id.name} in room #{room.number}"
          else
            @errors << "Failed to assign tenant to room: #{assignment.errors.full_messages.join(', ')}"
            puts "Failed to assign tenant to room: #{assignment.errors.full_messages.join(', ')}"
          end
        end
        
        return existing_tenant_by_id
      end
    end
    
    # Nếu không tìm thấy theo id_number, tìm hoặc tạo theo tên
    tenant = Tenant.find_or_initialize_by(name: tenant_name)
    
    if tenant.new_record?
      tenant.phone = tenant_phone.presence || ''
      tenant.email = ''
      tenant.id_number = tenant_id
      
      if tenant.save
        @imported_count[:tenants] += 1
        puts "Successfully created tenant: #{tenant.name} with ID: #{tenant.id_number}"
      else
        @errors << "Failed to create tenant #{tenant_name}: #{tenant.errors.full_messages.join(', ')}"
        puts "Failed to create tenant #{tenant_name}: #{tenant.errors.full_messages.join(', ')}"
        return nil
      end
    else
      # Cập nhật thông tin cho người thuê hiện có
      updated = false
      
      if tenant.phone.blank? && tenant_phone.present?
        tenant.phone = tenant_phone
        updated = true
      end
      
      if tenant.id_number.blank? && tenant_id.present?
        tenant.id_number = tenant_id
        updated = true
      end
      
      if updated && !tenant.save
        puts "Failed to update info for existing tenant: #{tenant.errors.full_messages.join(', ')}"
      end
    end
    
    # Create room assignment if not exists
    unless RoomAssignment.exists?(room: room, tenant: tenant, active: true)
      assignment = RoomAssignment.new(
        room: room,
        tenant: tenant,
        start_date: Date.new(@billing_year, @billing_month, 1),
        active: true
      )
      
      if assignment.save
        puts "Successfully created room assignment for #{tenant.name} in room #{room.number}"
      else
        @errors << "Failed to assign tenant to room: #{assignment.errors.full_messages.join(', ')}"
        puts "Failed to assign tenant to room: #{assignment.errors.full_messages.join(', ')}"
      end
    end
    
    tenant
  end
  
  def create_tenant_and_assignment(tenant_name, room)
    # Tìm thông tin người thuê trong row hiện tại
    id_number = get_cell_value(row, :id_number).to_s.strip
    
    # Nếu không tìm thấy ID trong excel, tạo một ID tạm thời
    if id_number.blank?
      # Tạo ID từ tên + phòng để đảm bảo duy nhất
      id_number = "ID-#{tenant_name.parameterize}-#{room.number.parameterize}-#{SecureRandom.hex(3)}"
      puts "No ID number found for tenant #{tenant_name}, generated: #{id_number}"
    else
      puts "Found ID number for tenant #{tenant_name}: #{id_number}"
    end
    
    tenant = Tenant.find_or_initialize_by(name: tenant_name)
    
    if tenant.new_record?
      tenant.phone = ''  # Set default values
      tenant.email = ''
      tenant.id_number = id_number  # Gán CCCD/CMND hoặc ID tạm thời
      
      if tenant.save
        @imported_count[:tenants] += 1
        puts "Successfully created tenant: #{tenant.name} with ID: #{tenant.id_number}"
      else
        @errors << "Failed to create tenant #{tenant_name}: #{tenant.errors.full_messages.join(', ')}"
        puts "Failed to create tenant #{tenant_name}: #{tenant.errors.full_messages.join(', ')}"
        return nil
      end
    elsif tenant.id_number.blank? && id_number.present?
      # Cập nhật ID nếu người thuê đã tồn tại nhưng chưa có ID
      tenant.id_number = id_number
      if tenant.save
        puts "Updated existing tenant #{tenant.name} with new ID: #{id_number}"
      else
        puts "Failed to update ID for existing tenant: #{tenant.errors.full_messages.join(', ')}"
      end
    end
    
    # Create room assignment if not exists
    unless RoomAssignment.exists?(room: room, tenant: tenant, active: true)
      assignment = RoomAssignment.new(
        room: room,
        tenant: tenant,
        start_date: Date.new(@billing_year, @billing_month, 1),
        active: true
      )
      
      if assignment.save
        puts "Successfully created room assignment for #{tenant.name} in room #{room.number}"
      else
        @errors << "Failed to assign tenant to room: #{assignment.errors.full_messages.join(', ')}"
        puts "Failed to assign tenant to room: #{assignment.errors.full_messages.join(', ')}"
      end
    end
    
    tenant
  end
  
  def create_utility_readings(row, room)
    # Make sure we have valid billing month and year before proceeding
    unless @billing_month.present? && @billing_year.present? && 
            @billing_month.between?(1, 12) && @billing_year.between?(2000, 2100)
      puts "Invalid billing period: #{@billing_month}/#{@billing_year}"
      @errors << "Invalid billing period: #{@billing_month}/#{@billing_year}"
      return
    end
    
    begin
      billing_date = Date.new(@billing_year, @billing_month, 1)
      puts "Creating utility readings for room #{room.number} with date #{billing_date}"
    rescue ArgumentError => e
      @errors << "Invalid billing date: #{@billing_month}/#{@billing_year}. Error: #{e.message}"
      return
    end
    
    # Electricity reading
    elec_start = get_cell_value(row, :elec_start).to_f
    elec_end = get_cell_value(row, :elec_end).to_f
    
    puts "Electricity readings: #{elec_start} → #{elec_end}"
    
    # If elec_start or elec_end is missing, try to get from elec_usage column
    if (!elec_start || !elec_end || elec_start == 0 || elec_end == 0) && @column_indices[:elec_usage]
      elec_usage_text = get_cell_value(row, :elec_usage).to_s
      puts "Trying to extract electricity from usage text: #{elec_usage_text}"
      # Try to extract start and end values if they're in format "start → end" or "start - end"
      if elec_usage_text =~ /(\d+)(?:\s*(?:→|-|to)\s*)(\d+)/
        elec_start = $1.to_f
        elec_end = $2.to_f
        puts "Extracted electricity: #{elec_start} → #{elec_end}"
      end
    end
    
    # Water reading
    water_start = get_cell_value(row, :water_start).to_f
    water_end = get_cell_value(row, :water_end).to_f
    
    puts "Water readings: #{water_start} → #{water_end}"
    
    # If water_start or water_end is missing, try to get from water_usage column
    if (!water_start || !water_end || water_start == 0 || water_end == 0) && @column_indices[:water_usage]
      water_usage_text = get_cell_value(row, :water_usage).to_s
      puts "Trying to extract water from usage text: #{water_usage_text}"
      # Try to extract start and end values if they're in format "start → end" or "start - end"
      if water_usage_text =~ /(\d+)(?:\s*(?:→|-|to)\s*)(\d+)/
        water_start = $1.to_f
        water_end = $2.to_f
        puts "Extracted water: #{water_start} → #{water_end}"
      end
    end
    
    # In the actual model, we have electricity_reading and water_reading
    # instead of utility_type and reading_value
    if elec_start && elec_end && elec_start >= 0 && elec_end >= elec_start
      begin
        # Find existing reading or create a new one
        reading = UtilityReading.find_or_initialize_by(
          room_id: room.id,
          reading_date: billing_date
        )
        
        # Update both new and existing readings
        reading.electricity_reading = elec_end
        # We don't directly store previous_reading in the model, 
        # but we'll handle it when calculating usage
        
        if reading.save
          @imported_count[:utility_readings] += 1 if reading.previous_changes.any?
          puts "Successfully saved electricity reading: #{elec_end} (previous: #{elec_start})"
        else
          @errors << "Failed to create utility reading for room #{room.number}: #{reading.errors.full_messages.join(', ')}"
          puts "Failed to save utility reading: #{reading.errors.full_messages.join(', ')}"
        end
      rescue => e
        @errors << "Error creating utility reading: #{e.message}"
        puts "Exception creating utility reading: #{e.message}"
      end
    else
      puts "Invalid electricity readings: #{elec_start} → #{elec_end}"
    end
    
    # Water readings are also stored in the same record
    if water_start && water_end && water_start >= 0 && water_end >= water_start
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
          puts "Successfully saved water reading: #{water_end} (previous: #{water_start})"
        else
          @errors << "Failed to update water reading for room #{room.number}: #{reading.errors.full_messages.join(', ')}"
          puts "Failed to save water reading: #{reading.errors.full_messages.join(', ')}"
        end
      rescue => e
        @errors << "Error updating water reading: #{e.message}"
        puts "Exception updating water reading: #{e.message}"
      end
    else
      puts "Invalid water readings: #{water_start} → #{water_end}"
    end
  end

  def create_bill(row, room, tenant = nil)
    unless @billing_month.present? && @billing_year.present? && 
            @billing_month.between?(1, 12) && @billing_year.between?(2000, 2100)
      puts "Invalid billing period for bill: #{@billing_month}/#{@billing_year}"
      return
    end
    
    begin
      billing_date = Date.new(@billing_year, @billing_month, 1)
      due_date = billing_date + 10.days  # Due 10 days after billing date
      puts "Creating bill for room #{room.number} with date #{billing_date}"
    rescue ArgumentError => e
      @errors << "Invalid billing date: #{@billing_month}/#{@billing_year}. Error: #{e.message}"
      return
    end
    
    # Get values for bill
    room_fee = get_cell_value(row, :room_fee).to_f
    elec_amount = get_cell_value(row, :elec_amount).to_f
    water_amount = get_cell_value(row, :water_amount).to_f
    wifi_fee = get_cell_value(row, :wifi_fee).to_f
    trash_fee = get_cell_value(row, :trash_fee).to_f
    service_fee = get_cell_value(row, :service_fee).to_f
    total_amount = get_cell_value(row, :total_amount).to_f
    payment_status = get_cell_value(row, :payment_status).to_s.strip.downcase
    
    puts "Bill values: room_fee=#{room_fee}, elec=#{elec_amount}, water=#{water_amount}, wifi=#{wifi_fee}, trash=#{trash_fee}, service=#{service_fee}, total=#{total_amount}"
    
    # Use provided tenant or find current tenant for bill
    unless tenant
      tenant = room.current_tenant
      unless tenant
        @errors << "No active tenant found for room #{room.number}. Bill cannot be created."
        puts "No active tenant found for room #{room.number}. Bill cannot be created."
        return
      end
    end
    
    puts "Creating bill for tenant: #{tenant.name}"
    
    # Find the active room assignment between tenant and room
    room_assignment = RoomAssignment.where(room: room, tenant: tenant, active: true).first
    
    unless room_assignment
      @errors << "No active room assignment found for tenant #{tenant.name} in room #{room.number}. Bill cannot be created."
      puts "No active room assignment found for tenant #{tenant.name} in room #{room.number}. Bill cannot be created."
      return
    end
    
    # Calculate utility charges
    utility_charges = elec_amount + water_amount
    additional_charges = (wifi_fee || 0) + (trash_fee || 0) + (service_fee || 0)
    
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
      bill.other_fees = additional_charges if additional_charges > 0
      
      # Calculate total if not provided
      if total_amount > 0
        bill.total_amount = total_amount
      else
        # Let the model calculate the total based on individual fees
        bill.calculate_total if bill.respond_to?(:calculate_total)
      end
      
      # Set status based on payment status field (if exists)
      if payment_status.present?
        if payment_status.include?('đã thanh toán') || payment_status.include?('paid')
          bill.status = 'paid'
          # payment_date is a virtual attribute that returns updated_at when status is 'paid'
        else
          bill.status = 'unpaid'
        end
      else
        bill.status = 'unpaid'
      end
      
      # Set notes with breakdown of fees
      notes = []
      notes << "Room Fee: #{room_fee}" if room_fee > 0
      notes << "Electricity: #{elec_amount}" if elec_amount > 0
      notes << "Water: #{water_amount}" if water_amount > 0
      notes << "WiFi: #{wifi_fee}" if wifi_fee && wifi_fee > 0
      notes << "Trash: #{trash_fee}" if trash_fee && trash_fee > 0
      notes << "Service Fee: #{service_fee}" if service_fee && service_fee > 0
      bill.notes = notes.join(", ")
      
      if bill.save
        if bill_is_new
          @imported_count[:bills] += 1 
          puts "Successfully created bill: #{bill.id}"
        else
          puts "Successfully updated bill: #{bill.id}"
        end
      else
        @errors << "Failed to create bill for room #{room.number}: #{bill.errors.full_messages.join(', ')}"
        puts "Failed to save bill: #{bill.errors.full_messages.join(', ')}"
      end
    rescue => e
      @errors << "Error creating bill: #{e.message}"
      puts "Exception when creating bill: #{e.message}"
      puts e.backtrace.join("\n") if Rails.env.development?
    end
  end
end