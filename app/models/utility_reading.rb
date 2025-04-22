class UtilityReading < ApplicationRecord
  belongs_to :room
  
  validates :reading_date, presence: true
  validates :electricity_reading, numericality: { greater_than_or_equal_to: 0 }
  validates :water_reading, numericality: { greater_than_or_equal_to: 0 }
  
  def previous_reading
    UtilityReading.where(room_id: room_id)
                  .where('reading_date < ?', reading_date)
                  .order(reading_date: :desc)
                  .first
  end
  
  def electricity_usage
    prev = previous_reading
    prev ? [electricity_reading - prev.electricity_reading, 0].max : 0
  end
  
  def water_usage
    prev = previous_reading
    prev ? [water_reading - prev.water_reading, 0].max : 0
  end
  
  def electricity_cost
    electricity_usage * electricity_unit_price
  end
  
  def water_cost
    water_usage * water_unit_price
  end
end
