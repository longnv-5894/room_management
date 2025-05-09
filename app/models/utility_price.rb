class UtilityPrice < ApplicationRecord
  belongs_to :building, optional: true

  validates :electricity_unit_price, :water_unit_price, :service_charge, presence: true,
                                                                          numericality: { greater_than_or_equal_to: 0 }
  validates :effective_date, presence: true

  # Get the current active price configuration (the latest one)
  def self.current(building_id = nil)
    if building_id
      where(building_id: building_id).order(effective_date: :desc).first ||
      where(building_id: nil).order(effective_date: :desc).first ||
      create_default
    else
      order(effective_date: :desc).first || create_default
    end
  end

  # Find the price configuration that was active on a specific date
  def self.for_date(date, building_id = nil)
    if building_id
      prices = where("effective_date <= ? AND building_id = ?", date, building_id)
               .order(effective_date: :desc)

      # If no building-specific prices, fall back to global prices
      prices = where("effective_date <= ? AND building_id IS NULL", date)
               .order(effective_date: :desc) if prices.empty?

      prices.first || create_default
    else
      where("effective_date <= ?", date)
        .order(effective_date: :desc)
        .first || create_default
    end
  end

  # Create a default price configuration if none exists
  def self.create_default
    create!(
      electricity_unit_price: 3500,  # Default values in VND
      water_unit_price: 15000,
      service_charge: 200000,
      effective_date: Date.today,
      notes: "Default price configuration"
    )
  end

  # Format for display - return numbers only since view helpers will handle formatting
  def electricity_unit_price_formatted
    electricity_unit_price
  end

  def water_unit_price_formatted
    water_unit_price
  end

  def service_charge_formatted
    service_charge
  end
end
