# This file contains seed data for the room management system
# based on typical rental information for April 2025

# Load locations data first (countries, cities, districts, wards)
require_relative 'seeds/locations'

# Load utility prices data
# require_relative 'seeds/utility_prices'

# Clear existing data
puts "Clearing existing data..."
Vehicle.destroy_all
OperatingExpense.destroy_all
Bill.destroy_all
UtilityReading.destroy_all
Contract.destroy_all  # Add this line to destroy contracts first
RoomAssignment.destroy_all
Room.destroy_all
Tenant.destroy_all
UtilityPrice.destroy_all
Building.destroy_all
User.destroy_all
OperatingExpense.destroy_all
DeviceUser.destroy_all
UnlockRecord.destroy_all
SmartDevice.destroy_all


# Note: We don't clear location data here as it's handled in the locations seed file

# Create admin user
puts "Creating admin user..."
user = User.create!(
  name: 'Nguyễn Viết Long',
  email: 'admin@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  phone: '0787027768',
  gender: 'male',
  date_of_birth: Date.new(1994, 8, 5),
  id_number: '001094008487',
  id_issue_date: Date.new(2021, 12, 27),
  id_issue_place: 'Cục cảnh sát quản lý hành chính về trật tự xã hội',
  address: 'số 18 ngõ 139 đường Nguyễn Ngọc Vũ, Cầu Giấy Hà Nội'
)

# Create another user
puts "Creating another user..."
User.create!(
  name: 'Trần Thị Hương',
  email: 'huong@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  phone: '0912345678',
  gender: 'female',
  date_of_birth: Date.new(1992, 5, 15),
  id_number: '001092765432',
  id_issue_date: Date.new(2020, 8, 10),
  id_issue_place: 'Cục cảnh sát quản lý hành chính về trật tự xã hội',
  address: 'số 25 Nguyễn Chí Thanh, Đống Đa, Hà Nội'
)

# Create buildings
# puts "Creating buildings..."
# # Get Vietnam and some cities/districts/wards for our seed data
# vietnam = Country.find_by(name: "Việt Nam") # Updated to use Vietnamese name
# hcmc = City.find_by(name: "Thành phố Hồ Chí Minh") # Updated to use Vietnamese name
# district_1 = District.find_by(name: "Quận 1", city: hcmc) # Updated to use Vietnamese name
# district_3 = District.find_by(name: "Quận 3", city: hcmc) # Updated to use Vietnamese name
# district_5 = District.find_by(name: "Quận 5", city: hcmc) # Updated to use Vietnamese name
# ben_nghe = Ward.find_by(name: "Bến Nghé", district: district_1) # Updated to use Vietnamese name

# buildings = [
#   {
#     name: 'Building A',
#     address: '123 Nguyễn Huệ, Quận 1, TP.HCM', # Updated to use Vietnamese address
#     street_address: '123 Nguyễn Huệ',
#     country: vietnam,
#     city: hcmc,
#     district: district_1,
#     ward: ben_nghe,
#     description: 'Khu chung cư 3 tầng hiện đại với vị trí thuận tiện gần trung tâm thành phố',
#     num_floors: 3,
#     year_built: 2021,
#     total_area: 800.0,
#     status: 'active',
#     user: user
#   },
#   {
#     name: 'Building B',
#     address: '456 Lê Lợi, Quận 3, TP.HCM', # Updated to use Vietnamese address
#     street_address: '456 Lê Lợi',
#     country: vietnam,
#     city: hcmc,
#     district: district_3,
#     description: 'Phòng trọ giá cả phải chăng trong khu dân cư yên tĩnh',
#     num_floors: 2,
#     year_built: 2019,
#     total_area: 500.0,
#     status: 'active',
#     user: user
#   },
#   {
#     name: 'Building C',
#     address: '789 Trần Hưng Đạo, Quận 5, TP.HCM', # Updated to use Vietnamese address
#     street_address: '789 Trần Hưng Đạo',
#     country: vietnam,
#     city: hcmc,
#     district: district_5,
#     description: 'Tòa nhà mới được cải tạo với tiện nghi hiện đại',
#     num_floors: 4,
#     year_built: 2018,
#     total_area: 1200.0,
#     status: 'under_construction',
#     user: user
#   }
# ]

# created_buildings = buildings.map do |building_data|
#   Building.create!(building_data)
# end

# # Create rooms
# puts "Creating rooms..."
# rooms = [
#   # Building A rooms
#   { number: '101', floor: 1, area: 25.0, monthly_rent: 2500000, status: 'occupied', building: created_buildings[0] },
#   { number: '102', floor: 1, area: 30.0, monthly_rent: 3000000, status: 'occupied', building: created_buildings[0] },
#   { number: '103', floor: 1, area: 20.0, monthly_rent: 2000000, status: 'occupied', building: created_buildings[0] },
#   { number: '201', floor: 2, area: 25.0, monthly_rent: 2700000, status: 'occupied', building: created_buildings[0] },
#   { number: '202', floor: 2, area: 30.0, monthly_rent: 3200000, status: 'occupied', building: created_buildings[0] },
#   { number: '203', floor: 2, area: 20.0, monthly_rent: 2200000, status: 'available', building: created_buildings[0] },
#   { number: '301', floor: 3, area: 25.0, monthly_rent: 2900000, status: 'occupied', building: created_buildings[0] },
#   { number: '302', floor: 3, area: 30.0, monthly_rent: 3400000, status: 'occupied', building: created_buildings[0] },
#   { number: '303', floor: 3, area: 20.0, monthly_rent: 2400000, status: 'maintenance', building: created_buildings[0] },

#   # Building B rooms
#   { number: '101', floor: 1, area: 22.0, monthly_rent: 2200000, status: 'occupied', building: created_buildings[1] },
#   { number: '102', floor: 1, area: 25.0, monthly_rent: 2500000, status: 'occupied', building: created_buildings[1] },
#   { number: '103', floor: 1, area: 22.0, monthly_rent: 2200000, status: 'available', building: created_buildings[1] },
#   { number: '201', floor: 2, area: 22.0, monthly_rent: 2300000, status: 'occupied', building: created_buildings[1] },
#   { number: '202', floor: 2, area: 25.0, monthly_rent: 2600000, status: 'available', building: created_buildings[1] },
#   { number: '203', floor: 2, area: 22.0, monthly_rent: 2300000, status: 'maintenance', building: created_buildings[1] }
# ]

# created_rooms = rooms.map do |room_data|
#   Room.create!(room_data)
# end

# # Create tenants
# puts "Creating tenants..."
# tenants = [
#   { name: 'Nguyen Van A', phone: '0901234567', email: 'nguyenvana@example.com', id_number: '001234567890', move_in_date: '2024-01-15' },
#   { name: 'Tran Thi B', phone: '0912345678', email: 'tranthib@example.com', id_number: '002345678901', move_in_date: '2024-02-01' },
#   { name: 'Le Van C', phone: '0923456789', email: 'levanc@example.com', id_number: '003456789012', move_in_date: '2024-02-15' },
#   { name: 'Pham Thi D', phone: '0934567890', email: 'phamthid@example.com', id_number: '004567890123', move_in_date: '2024-03-01' },
#   { name: 'Hoang Van E', phone: '0945678901', email: 'hoangvane@example.com', id_number: '005678901234', move_in_date: '2024-03-15' },
#   { name: 'Nguyen Thi F', phone: '0956789012', email: 'nguyenthif@example.com', id_number: '006789012345', move_in_date: '2024-04-01' },
#   { name: 'Tran Van G', phone: '0967890123', email: 'tranvang@example.com', id_number: '007890123456', move_in_date: '2024-01-05' },
#   { name: 'Le Thi H', phone: '0978901234', email: 'lethih@example.com', id_number: '008901234567', move_in_date: '2024-02-10' },
#   # Adding additional tenants
#   { name: 'Pham Van I', phone: '0989012345', email: 'phamvani@example.com', id_number: '009012345678', move_in_date: '2024-03-10' },
#   { name: 'Vo Thi J', phone: '0990123456', email: 'vothij@example.com', id_number: '010123456789', move_in_date: '2024-02-20' },
#   { name: 'Truong Van K', phone: '0901234567', email: 'truongvank@example.com', id_number: '011234567890', move_in_date: '2024-01-20' },
#   { name: 'Do Thi L', phone: '0912345678', email: 'dothil@example.com', id_number: '012345678901', move_in_date: '2024-03-05' }
# ]

# created_tenants = tenants.map do |tenant_data|
#   Tenant.create!(tenant_data)
# end

# # Create room assignments
# puts "Creating room assignments..."
# room_assignments = []

# # For each occupied room, create assignments
# occupied_rooms = created_rooms.select { |room| room.status == 'occupied' }

# occupied_rooms.each_with_index do |room, index|
#   # Select tenants for this room
#   num_tenants_for_room = [ 1, 1, 1, 2, 3 ].sample # Most rooms have 1 tenant, some have 2 or 3
#   room_tenants = created_tenants.sample(num_tenants_for_room)

#   room_tenants.each_with_index do |tenant, tenant_index|
#     # First tenant in each room becomes the representative
#     is_representative = (tenant_index == 0)

#     # Only representative tenant gets deposit
#     deposit = is_representative ? room.monthly_rent : nil

#     # Create the assignment
#     assignment = {
#       room: room,
#       tenant: tenant,
#       start_date: Date.new(2024, 1, 15) + rand(80),
#       deposit_amount: deposit,
#       active: true,
#       is_representative_tenant: is_representative
#     }

#     room_assignments << assignment

#     # Remove this tenant from available tenants to avoid duplicates
#     created_tenants.delete(tenant)

#     # Break if we run out of tenants
#     break if created_tenants.empty?
#   end

#   break if created_tenants.empty?
# end

# created_assignments = room_assignments.map do |assignment_data|
#   RoomAssignment.create!(assignment_data)
# end

# # Create utility readings (past 3 months)
# puts "Creating utility readings..."

# # Current date (as defined in context)
# current_date = Date.new(2025, 5, 9)
# current_month = current_date.month
# current_year = current_date.year

# # Calculate billing periods
# billing_periods = [
#   Date.new(current_year, current_month - 2, 1),  # March 2025
#   Date.new(current_year, current_month - 1, 1),  # April 2025
#   Date.new(current_year, current_month, 1)       # May 2025 (current month)
# ]

# # For each room with a tenant, create utility readings for the past 3 months
# occupied_rooms = created_rooms.select { |room| room.status == 'occupied' }

# occupied_rooms.each do |room|
#   # Initial readings (2 months ago - March 2025)
#   initial_electricity = rand(100..300)
#   initial_water = rand(5..15)

#   UtilityReading.create!(
#     room: room,
#     reading_date: billing_periods[0],
#     electricity_reading: initial_electricity,
#     water_reading: initial_water
#   )

#   # Last month readings (April 2025)
#   april_electricity = initial_electricity + rand(30..100)
#   april_water = initial_water + rand(2..5)

#   UtilityReading.create!(
#     room: room,
#     reading_date: billing_periods[1],
#     electricity_reading: april_electricity,
#     water_reading: april_water
#   )

#   # Current month readings (May 2025)
#   may_electricity = april_electricity + rand(30..100)
#   may_water = april_water + rand(2..5)

#   UtilityReading.create!(
#     room: room,
#     reading_date: billing_periods[2],
#     electricity_reading: may_electricity,
#     water_reading: may_water
#   )
# end

# # Create bills for current and previous month
# puts "Creating bills for the past months..."

# # Function to create bills for a specific month
# def create_bills_for_month(rooms, billing_date)
#   # Get the current month utility prices
#   month_utility_prices = UtilityPrice.where('effective_date <= ?', billing_date)
#                                     .order(effective_date: :desc)
#                                     .first

#   return unless month_utility_prices

#   # Default prices if no specific prices found
#   electricity_rate = month_utility_prices.electricity_unit_price || 4000
#   water_rate = month_utility_prices.water_unit_price || 15000
#   service_charge = month_utility_prices.service_charge || 100000

#   rooms.each do |room|
#     # Get the readings for current and previous month
#     current_reading = UtilityReading.where(room: room)
#                                    .where('reading_date <= ?', billing_date)
#                                    .order(reading_date: :desc)
#                                    .first

#     previous_reading = UtilityReading.where(room: room)
#                                     .where('reading_date < ?', billing_date)
#                                     .order(reading_date: :desc)
#                                     .first

#     next unless current_reading && previous_reading

#     # Calculate usage and fees
#     electricity_usage = current_reading.electricity_reading - previous_reading.electricity_reading
#     water_usage = current_reading.water_reading - previous_reading.water_reading

#     electricity_fee = electricity_usage * electricity_rate
#     water_fee = water_usage * water_rate

#     # Get all active room assignments for this room
#     active_assignments = room.room_assignments.where(active: true)
#     tenant_count = active_assignments.count

#     next if tenant_count == 0

#     # Calculate fee per tenant
#     total_service_fee = service_charge * tenant_count

#     # Create bills for each tenant, with the main tenant paying all utilities
#     active_assignments.each_with_index do |assignment, index|
#       is_main_tenant = assignment.is_representative_tenant

#       # Create due date 10 days after billing date
#       due_date = billing_date + 10.days

#       # Previous debts or overpayments (randomly added to some bills)
#       prev_debt = index == 0 && rand(10) > 7 ? rand(100000..300000) : 0
#       overpayment = index == 0 && prev_debt == 0 && rand(10) > 8 ? rand(50000..150000) : 0

#       # Create bill with additional realistic details
#       bill = Bill.create!(
#         room_assignment: assignment,
#         billing_date: billing_date,
#         due_date: due_date,
#         room_fee: room.monthly_rent / tenant_count,  # Split room fee equally
#         electricity_fee: is_main_tenant ? electricity_fee : 0,  # Only main tenant pays for electricity
#         water_fee: is_main_tenant ? water_fee : 0,             # Only main tenant pays for water
#         service_fee: service_charge,                          # Each tenant pays service fee
#         previous_debt: prev_debt,
#         overpayment: overpayment,
#         # For bills older than 15 days, mark many as paid
#         status: (Date.today - billing_date > 15 && rand(10) > 2) ? 'paid' : 'unpaid',
#         payment_date: (Date.today - billing_date > 15 && rand(10) > 2) ? billing_date + rand(1..10).days : nil,
#         notes: "Electricity: #{electricity_usage.to_f} kWh, Water: #{water_usage.to_f} m³"
#       )
#     end
#   end
# end

# # Create bills for April and May 2025
# [ billing_periods[0], billing_periods[1] ].each do |billing_date|
#   create_bills_for_month(occupied_rooms, billing_date)
# end

# # Create vehicles
# puts "Creating vehicles..."
# vehicle_types = [ 'car', 'motorcycle', 'bicycle', 'scooter', 'other' ]
# brands = {
#   'car' => [ 'Toyota', 'Honda', 'Ford', 'Mazda', 'Kia', 'Hyundai' ],
#   'motorcycle' => [ 'Honda', 'Yamaha', 'Suzuki', 'SYM', 'Piaggio', 'Kawasaki' ],
#   'bicycle' => [ 'Giant', 'Trek', 'Asama', 'Thong Nhat', 'Jett' ],
#   'scooter' => [ 'Vespa', 'Honda', 'Yamaha', 'Gogoro' ],
#   'other' => [ 'Misc' ]
# }
# colors = [ 'Black', 'White', 'Red', 'Blue', 'Silver', 'Grey', 'Green', 'Yellow' ]

# # Get all tenants from database since created_tenants array might be empty at this point
# all_tenants = Tenant.all

# # Give approximately 60% of tenants vehicles
# tenant_sample = all_tenants.sample((all_tenants.length * 0.6).to_i)

# tenant_sample.each do |tenant|
#   # Some tenants will have multiple vehicles
#   vehicle_count = rand(1..2)

#   vehicle_count.times do
#     vehicle_type = vehicle_types.sample
#     brand = brands[vehicle_type].sample

#     model_year = (2015..2025).to_a.sample
#     models = {
#       'car' => [ 'Vios', 'City', 'Ranger', 'CX-5', 'Seltos', 'Accent' ],
#       'motorcycle' => [ 'Wave', 'Exciter', 'Raider', 'Angel', 'Liberty', 'Ninja' ],
#       'bicycle' => [ 'Mountain', 'Road', 'City', 'ATX', 'FX' ],
#       'scooter' => [ 'Sprint', 'Lead', 'NVX', 'Viva' ],
#       'other' => [ 'Custom' ]
#     }

#     model = models[vehicle_type].sample

#     # Create license plate based on vehicle type
#     license_plate = if vehicle_type == 'car'
#                       "#{(29..99).to_a.sample}A-#{rand(100..999)}.#{rand(10..99)}"
#     elsif vehicle_type == 'motorcycle'
#                       "#{(29..99).to_a.sample}B-#{rand(100..999)}.#{rand(10..99)}"
#     elsif vehicle_type == 'scooter'
#                       "#{(29..99).to_a.sample}K-#{rand(100..999)}.#{rand(10..99)}"
#     else
#                       # Bicycles and others get a placeholder ID number
#                       "ID-#{rand(1000..9999)}"
#     end

#     # Add optional notes to some vehicles
#     notes_options = [
#       "Insurance expires on #{rand(1..12)}/#{rand(2025..2026)}",
#       "Registration renewal needed",
#       "Parking space ##{rand(1..20)}",
#       nil, nil, nil  # Higher chance of no notes
#     ]

#     Vehicle.create!(
#       tenant: tenant,
#       license_plate: license_plate,
#       vehicle_type: vehicle_type,
#       brand: brand,
#       model: "#{model} #{model_year}",
#       color: colors.sample,
#       notes: notes_options.sample
#     )
#   end
# end

# # Create operating expenses
# puts "Creating operating expenses..."
# expense_categories = [
#   'utilities', 'maintenance', 'repairs', 'cleaning', 'security',
#   'taxes', 'staff_salary', 'electric', 'water', 'internet', 'miscellaneous'
# ]

# expense_descriptions = {
#   'utilities' => [ 'Common area electricity', 'Hallway lighting', 'Elevator power consumption' ],
#   'maintenance' => [ 'Regular building maintenance', 'Preventive maintenance check', 'Equipment servicing' ],
#   'repairs' => [ 'Roof leak repair', 'Plumbing fix', 'Electrical wiring repair', 'Wall repainting', 'Door hinge replacement' ],
#   'cleaning' => [ 'Monthly cleaning service', 'Waste disposal', 'Cleaning supplies purchase' ],
#   'security' => [ 'Security guard salary', 'CCTV maintenance', 'Security equipment upgrade' ],
#   'taxes' => [ 'Property tax payment', 'Annual property tax', 'Business permit renewal' ],
#   'staff_salary' => [ 'Building manager salary', 'Maintenance staff wages', 'Administrative staff salary' ],
#   'electric' => [ 'Common area electricity bill', 'Pump system electric consumption' ],
#   'water' => [ 'Common area water bill', 'Garden watering system' ],
#   'internet' => [ 'Building wifi service', 'Management office internet connection' ],
#   'miscellaneous' => [ 'Office supplies', 'Misc administrative expenses', 'Unexpected expenses' ]
# }

# # Create expenses for past 3 months for each building
# billing_periods.each do |month_start|
#   created_buildings.each do |building|
#     # Create 5-8 expenses per month per building
#     expense_count = rand(5..8)

#     expense_count.times do
#       category = expense_categories.sample

#       OperatingExpense.create!(
#         building: building,
#         category: category,
#         description: expense_descriptions[category].sample,
#         amount: rand(200000..5000000),  # 200,000 to 5,000,000 VND
#         expense_date: month_start + rand(0..28)  # Random day in the month
#       )
#     end
#   end
# end

# # Create contracts for some room assignments
# puts "Creating contracts..."

# # Sample 70% of room assignments to have contracts
# contract_assignments = RoomAssignment.where(is_representative_tenant: true).to_a.sample((RoomAssignment.where(is_representative_tenant: true).count * 0.7).to_i)

# contract_assignments.each do |assignment|
#   contract_start = assignment.start_date
#   # Contract ends 6 or 12 months after start
#   contract_duration = [ 6, 12 ].sample
#   contract_end = contract_start + contract_duration.months

#   Contract.create!(
#     room_assignment: assignment,
#     start_date: contract_start,
#     end_date: contract_end,
#     rent_amount: assignment.room.monthly_rent,
#     deposit_amount: assignment.deposit_amount || assignment.room.monthly_rent,
#     status: Date.today >= contract_end ? 'expired' : 'active',
#     notes: "Initial contract for room #{assignment.room.number}"
#   )
# end

# puts "Seed data created successfully!"
