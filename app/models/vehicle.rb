class Vehicle < ApplicationRecord
  belongs_to :tenant
  
  validates :license_plate, presence: true, uniqueness: true
  validates :vehicle_type, presence: true
  
  # Common vehicle types
  VEHICLE_TYPES = [
    'car',
    'motorcycle',
    'bicycle',
    'scooter',
    'other'
  ].freeze
  
  # Return translated vehicle types for select options
  def self.vehicle_types_for_select
    VEHICLE_TYPES.map { |key| [I18n.t("vehicles.types.#{key}"), key] }
  end
  
  # Return translated vehicle type name
  def vehicle_type_name
    I18n.t("vehicles.types.#{vehicle_type}", default: vehicle_type)
  end
end