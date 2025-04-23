class UtilityPrice < ApplicationRecord
  validates :electricity_unit_price, :water_unit_price, :service_charge, presence: true,
                                                                          numericality: { greater_than_or_equal_to: 0 }
  validates :effective_date, presence: true
  
  # Get the current active price configuration (the latest one)
  def self.current
    order(effective_date: :desc).first || create_default
  end
  
  # Find the price configuration that was active on a specific date
  def self.for_date(date)
    where("effective_date <= ?", date)
      .order(effective_date: :desc)
      .first || create_default
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
