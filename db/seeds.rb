# This file contains seed data for the room management system
# based on typical rental information for April 2025

# Clear existing data
puts "Clearing existing data..."
Vehicle.destroy_all
OperatingExpense.destroy_all
Bill.destroy_all
UtilityReading.destroy_all
RoomAssignment.destroy_all
Room.destroy_all
Tenant.destroy_all
User.destroy_all

# Create admin user
puts "Creating admin user..."
User.create!(
  email: 'admin@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# Create rooms
puts "Creating rooms..."
rooms = [
  { number: '101', floor: 1, area: 25.0, monthly_rent: 2500000, status: 'occupied' },
  { number: '102', floor: 1, area: 30.0, monthly_rent: 3000000, status: 'occupied' },
  { number: '103', floor: 1, area: 20.0, monthly_rent: 2000000, status: 'occupied' },
  { number: '201', floor: 2, area: 25.0, monthly_rent: 2700000, status: 'occupied' },
  { number: '202', floor: 2, area: 30.0, monthly_rent: 3200000, status: 'occupied' },
  { number: '203', floor: 2, area: 20.0, monthly_rent: 2200000, status: 'available' },
  { number: '301', floor: 3, area: 25.0, monthly_rent: 2900000, status: 'occupied' },
  { number: '302', floor: 3, area: 30.0, monthly_rent: 3400000, status: 'occupied' },
  { number: '303', floor: 3, area: 20.0, monthly_rent: 2400000, status: 'maintenance' }
]

created_rooms = rooms.map do |room_data|
  Room.create!(room_data)
end

# Create tenants
puts "Creating tenants..."
tenants = [
  { name: 'Nguyen Van A', phone: '0901234567', email: 'nguyenvana@example.com', id_number: '001234567890', move_in_date: '2024-01-15' },
  { name: 'Tran Thi B', phone: '0912345678', email: 'tranthib@example.com', id_number: '002345678901', move_in_date: '2024-02-01' },
  { name: 'Le Van C', phone: '0923456789', email: 'levanc@example.com', id_number: '003456789012', move_in_date: '2024-02-15' },
  { name: 'Pham Thi D', phone: '0934567890', email: 'phamthid@example.com', id_number: '004567890123', move_in_date: '2024-03-01' },
  { name: 'Hoang Van E', phone: '0945678901', email: 'hoangvane@example.com', id_number: '005678901234', move_in_date: '2024-03-15' },
  { name: 'Nguyen Thi F', phone: '0956789012', email: 'nguyenthif@example.com', id_number: '006789012345', move_in_date: '2024-04-01' },
  { name: 'Tran Van G', phone: '0967890123', email: 'tranvang@example.com', id_number: '007890123456', move_in_date: '2024-01-05' },
  { name: 'Le Thi H', phone: '0978901234', email: 'lethih@example.com', id_number: '008901234567', move_in_date: '2024-02-10' }
]

created_tenants = tenants.map do |tenant_data|
  Tenant.create!(tenant_data)
end

# Create room assignments
puts "Creating room assignments..."
room_assignments = [
  { room: created_rooms[0], tenant: created_tenants[0], start_date: '2024-01-15', deposit_amount: 2500000, active: true },
  { room: created_rooms[1], tenant: created_tenants[1], start_date: '2024-02-01', deposit_amount: 3000000, active: true },
  { room: created_rooms[2], tenant: created_tenants[2], start_date: '2024-02-15', deposit_amount: 2000000, active: true },
  { room: created_rooms[3], tenant: created_tenants[3], start_date: '2024-03-01', deposit_amount: 2700000, active: true },
  { room: created_rooms[4], tenant: created_tenants[4], start_date: '2024-03-15', deposit_amount: 3200000, active: true },
  { room: created_rooms[6], tenant: created_tenants[5], start_date: '2024-04-01', deposit_amount: 2900000, active: true },
  { room: created_rooms[7], tenant: created_tenants[6], start_date: '2024-01-05', deposit_amount: 3400000, active: true }
]

created_assignments = room_assignments.map do |assignment_data|
  RoomAssignment.create!(assignment_data)
end

# Create utility readings (past 3 months)
puts "Creating utility readings..."

# Define electricity and water rates
electricity_rate = 3500 # VND per kWh
water_rate = 15000      # VND per cubic meter

# For each room with a tenant, create utility readings for the past 3 months
occupied_rooms = created_rooms.select { |room| room.status == 'occupied' }

occupied_rooms.each do |room|
  # Initial readings (February 2025)
  initial_electricity = rand(100..300)
  initial_water = rand(5..15)
  
  UtilityReading.create!(
    room: room,
    reading_date: Date.new(2025, 2, 28),
    electricity_reading: initial_electricity,
    water_reading: initial_water,
    electricity_unit_price: electricity_rate,
    water_unit_price: water_rate
  )
  
  # March 2025 readings (with some usage)
  march_electricity = initial_electricity + rand(30..100)
  march_water = initial_water + rand(2..5)
  
  UtilityReading.create!(
    room: room,
    reading_date: Date.new(2025, 3, 31),
    electricity_reading: march_electricity,
    water_reading: march_water,
    electricity_unit_price: electricity_rate,
    water_unit_price: water_rate
  )
  
  # April 2025 readings (current month)
  april_electricity = march_electricity + rand(30..100)
  april_water = march_water + rand(2..5)
  
  UtilityReading.create!(
    room: room,
    reading_date: Date.new(2025, 4, 20), # Current reading as of April 20, 2025
    electricity_reading: april_electricity,
    water_reading: april_water,
    electricity_unit_price: electricity_rate,
    water_unit_price: water_rate
  )
end

# Create bills for April 2025
puts "Creating bills for April 2025..."

occupied_rooms.each do |room|
  # Get the latest utility reading for the room (April 2025)
  april_reading = UtilityReading.where(room: room)
                                .where('reading_date >= ?', Date.new(2025, 4, 1))
                                .order(reading_date: :desc)
                                .first
                                
  # Get the previous reading (March 2025)
  march_reading = UtilityReading.where(room: room)
                               .where('reading_date >= ? AND reading_date < ?', Date.new(2025, 3, 1), Date.new(2025, 4, 1))
                               .order(reading_date: :desc)
                               .first
  
  if april_reading && march_reading
    # Calculate electricity and water usage
    electricity_usage = april_reading.electricity_reading - march_reading.electricity_reading
    water_usage = april_reading.water_reading - march_reading.water_reading
    
    # Calculate fees
    electricity_fee = electricity_usage * electricity_rate
    water_fee = water_usage * water_rate
    
    # Other fees (internet, garbage, etc.)
    other_fees = rand(100000..200000)
    
    # Get the room assignment
    assignment = room.room_assignments.where(active: true).first
    
    if assignment
      # Create bill
      Bill.create!(
        room_assignment: assignment,
        billing_date: Date.new(2025, 4, 1),
        due_date: Date.new(2025, 4, 15),
        room_fee: room.monthly_rent,
        electricity_fee: electricity_fee,
        water_fee: water_fee,
        other_fees: other_fees,
        status: ['unpaid', 'paid'].sample, # Use string values for enum
        notes: "Electricity: #{electricity_usage} kWh, Water: #{water_usage} m³"
      )
    end
  end
end

# Create vehicles
puts "Creating vehicles..."
vehicle_types = ['car', 'motorcycle', 'bicycle', 'scooter', 'other']
brands = {
  'car' => ['Toyota', 'Honda', 'Ford', 'Mazda', 'Kia', 'Hyundai'],
  'motorcycle' => ['Honda', 'Yamaha', 'Suzuki', 'SYM', 'Piaggio', 'Kawasaki'],
  'bicycle' => ['Giant', 'Trek', 'Asama', 'Thong Nhat', 'Jett'],
  'scooter' => ['Vespa', 'Honda', 'Yamaha', 'Gogoro'],
  'other' => ['Misc']
}
colors = ['Black', 'White', 'Red', 'Blue', 'Silver', 'Grey', 'Green', 'Yellow']

# Give approximately 60% of tenants vehicles
tenant_sample = created_tenants.sample((created_tenants.length * 0.6).to_i)

tenant_sample.each do |tenant|
  # Some tenants will have multiple vehicles
  vehicle_count = rand(1..2)
  
  vehicle_count.times do
    vehicle_type = vehicle_types.sample
    brand = brands[vehicle_type].sample
    
    model_year = (2015..2025).to_a.sample
    models = {
      'car' => ['Vios', 'City', 'Ranger', 'CX-5', 'Seltos', 'Accent'],
      'motorcycle' => ['Wave', 'Exciter', 'Raider', 'Angel', 'Liberty', 'Ninja'],
      'bicycle' => ['Mountain', 'Road', 'City', 'ATX', 'FX'],
      'scooter' => ['Sprint', 'Lead', 'NVX', 'Viva'],
      'other' => ['Custom']
    }
    
    model = models[vehicle_type].sample
    
    # Create license plate based on vehicle type
    license_plate = if vehicle_type == 'car'
                      "#{(29..99).to_a.sample}A-#{rand(100..999)}.#{rand(10..99)}"
                    elsif vehicle_type == 'motorcycle'
                      "#{(29..99).to_a.sample}B-#{rand(100..999)}.#{rand(10..99)}"
                    elsif vehicle_type == 'scooter'
                      "#{(29..99).to_a.sample}K-#{rand(100..999)}.#{rand(10..99)}"
                    else
                      # Bicycles and others get a placeholder ID number
                      "ID-#{rand(1000..9999)}"
                    end
    
    # Add optional notes to some vehicles
    notes_options = [
      "Insurance expires on #{rand(1..12)}/#{rand(2025..2026)}",
      "Registration renewal needed",
      "Parking space ##{rand(1..20)}",
      nil, nil, nil  # Higher chance of no notes
    ]
    
    Vehicle.create!(
      tenant: tenant,
      license_plate: license_plate,
      vehicle_type: vehicle_type,
      brand: brand,
      model: "#{model} #{model_year}",
      color: colors.sample,
      notes: notes_options.sample
    )
  end
end

# Create operating expenses
puts "Creating operating expenses..."
expense_categories = [
  'utilities', 'maintenance', 'repairs', 'cleaning', 'security', 
  'taxes', 'staff_salary', 'electric', 'water', 'internet', 'miscellaneous'
]

expense_descriptions = {
  'utilities' => ['Common area electricity', 'Hallway lighting', 'Elevator power consumption'],
  'maintenance' => ['Regular building maintenance', 'Preventive maintenance check', 'Equipment servicing'],
  'repairs' => ['Roof leak repair', 'Plumbing fix', 'Electrical wiring repair', 'Wall repainting', 'Door hinge replacement'],
  'cleaning' => ['Monthly cleaning service', 'Waste disposal', 'Cleaning supplies purchase'],
  'security' => ['Security guard salary', 'CCTV maintenance', 'Security equipment upgrade'],
  'taxes' => ['Property tax payment', 'Annual property tax', 'Business permit renewal'],
  'staff_salary' => ['Building manager salary', 'Maintenance staff wages', 'Administrative staff salary'],
  'electric' => ['Common area electricity bill', 'Pump system electric consumption'],
  'water' => ['Common area water bill', 'Garden watering system'],
  'internet' => ['Building wifi service', 'Management office internet connection'],
  'miscellaneous' => ['Office supplies', 'Misc administrative expenses', 'Unexpected expenses']
}

# Create expenses for February, March, and April 2025
[Date.new(2025, 2, 1), Date.new(2025, 3, 1), Date.new(2025, 4, 1)].each do |month_start|
  # Create 10-15 expenses per month
  expense_count = rand(10..15)
  
  expense_count.times do
    category = expense_categories.sample
    
    OperatingExpense.create!(
      category: category,
      description: expense_descriptions[category].sample,
      amount: rand(200000..5000000),  # 200,000 to 5,000,000 VND
      expense_date: month_start + rand(0..28)  # Random day in the month
    )
  end
end

puts "Seed data created successfully!"
