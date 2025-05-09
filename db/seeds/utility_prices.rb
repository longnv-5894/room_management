# Seed file for utility prices and configurations
# This file provides standard utility prices for electricity, water, and services

# Create standard utility prices for system use
puts "Creating standard utility prices..."

# Define an array of dates for the past year
dates = (0..12).map { |months_ago| Date.today.beginning_of_month - months_ago.months }.sort

# Set utility prices with increases over time to reflect inflation
prices = [
  # Start with base prices
  { date: dates[0], electricity: 3500, water: 15000, service: 100000 },
  { date: dates[1], electricity: 3600, water: 15500, service: 100000 },
  { date: dates[2], electricity: 3600, water: 15500, service: 100000 },
  { date: dates[3], electricity: 3700, water: 16000, service: 110000 },
  { date: dates[4], electricity: 3700, water: 16000, service: 110000 },
  { date: dates[5], electricity: 3800, water: 16500, service: 110000 },
  { date: dates[6], electricity: 3800, water: 16500, service: 110000 },
  { date: dates[7], electricity: 3900, water: 17000, service: 120000 },
  { date: dates[8], electricity: 3900, water: 17000, service: 120000 },
  { date: dates[9], electricity: 4000, water: 17500, service: 120000 },
  { date: dates[10], electricity: 4000, water: 17500, service: 120000 },
  { date: dates[11], electricity: 4100, water: 18000, service: 130000 },
  { date: dates[12], electricity: 4100, water: 18000, service: 130000 }
]

# Create a global price settings (not specific to any building)
prices.each do |price_data|
  puts "Creating utility price for #{price_data[:date].strftime('%B %Y')}..."

  # Check if price already exists for this date
  existing_price = UtilityPrice.find_by(effective_date: price_data[:date], building_id: nil)

  if existing_price
    puts "  - Updating existing price record"
    existing_price.update!(
      electricity_unit_price: price_data[:electricity],
      water_unit_price: price_data[:water],
      service_charge: price_data[:service],
      notes: "Standard system price for #{price_data[:date].strftime('%B %Y')}"
    )
  else
    puts "  - Creating new price record"
    UtilityPrice.create!(
      effective_date: price_data[:date],
      electricity_unit_price: price_data[:electricity],
      water_unit_price: price_data[:water],
      service_charge: price_data[:service],
      notes: "Standard system price for #{price_data[:date].strftime('%B %Y')}"
    )
  end
end

# Create building-specific prices for each building if needed
puts "Creating building-specific utility prices..."

# Only create building-specific prices if buildings exist
if Building.any?
  # Get the last 3 months
  recent_dates = dates.last(3)

  # For each building, create some custom prices that differ from the standard
  Building.find_each do |building|
    puts "Creating custom prices for building: #{building.name}"

    # Only create custom prices for one of the dates (most recent)
    custom_date = recent_dates.last

    # Get the standard price for reference
    standard_price = UtilityPrice.find_by(effective_date: custom_date, building_id: nil)

    if standard_price
      # Create a slightly different price for this building
      building_price = UtilityPrice.find_or_initialize_by(
        effective_date: custom_date,
        building_id: building.id
      )

      # Some buildings might have different pricing strategies
      if building.name.include?('A')
        # Premium building - higher service charge
        building_price.electricity_unit_price = standard_price.electricity_unit_price
        building_price.water_unit_price = standard_price.water_unit_price * 1.1  # 10% higher water price
        building_price.service_charge = standard_price.service_charge * 1.2  # 20% higher service charge
      elsif building.name.include?('B')
        # Budget-friendly building - lower service charge, higher utilities
        building_price.electricity_unit_price = standard_price.electricity_unit_price * 1.05  # 5% higher electricity
        building_price.water_unit_price = standard_price.water_unit_price * 1.05  # 5% higher water
        building_price.service_charge = standard_price.service_charge * 0.9  # 10% lower service charge
      else
        # Standard building with slight variations
        building_price.electricity_unit_price = standard_price.electricity_unit_price * 1.02  # 2% higher
        building_price.water_unit_price = standard_price.water_unit_price  # Same as standard
        building_price.service_charge = standard_price.service_charge * 1.05  # 5% higher service charge
      end

      building_price.notes = "Custom price for #{building.name} (#{custom_date.strftime('%B %Y')})"

      if building_price.save
        puts "  - Successfully created/updated custom price for #{building.name}"
      else
        puts "  - Failed to create custom price: #{building_price.errors.full_messages.join(', ')}"
      end
    end
  end
else
  puts "  - No buildings found, skipping building-specific prices"
end

puts "Utility price seeding completed successfully!"
