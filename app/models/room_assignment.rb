class RoomAssignment < ApplicationRecord
  belongs_to :room
  belongs_to :tenant
  has_many :bills, dependent: :destroy
  has_many :contracts, dependent: :destroy

  validates :start_date, presence: true
  validate :end_date_after_start_date, if: -> { end_date.present? }
  validate :only_one_representative_per_room, if: -> { is_representative_tenant? && active? }

  validates :room_fee_frequency, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :utility_fee_frequency, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  before_save :update_room_status
  before_save :ensure_only_representative_has_deposit
  before_validation :set_default_payment_frequencies

  # Used for displaying in select dropdowns
  def display_name
    "Room #{room.number} - #{tenant.name}#{is_representative_tenant ? ' (Representative)' : ''}"
  end

  # Make this tenant the representative for their room
  def make_representative!
    return if is_representative_tenant?

    RoomAssignment.transaction do
      # Find the current representative tenant for this room
      previous_representative = room.room_assignments
                                   .where(active: true, is_representative_tenant: true)
                                   .first

      # Get the important values from the previous representative
      previous_deposit = previous_representative&.deposit_amount
      previous_room_fee_frequency = previous_representative&.room_fee_frequency || 1
      previous_utility_fee_frequency = previous_representative&.utility_fee_frequency || 1

      # Remove representative status from any other tenant in this room
      # and clear their deposit amount (handled by the before_save callback)
      room.room_assignments
          .where(active: true, is_representative_tenant: true)
          .update_all(is_representative_tenant: false)

      # Set this tenant as the representative and transfer all representative values
      self.deposit_amount = previous_deposit
      self.room_fee_frequency = previous_room_fee_frequency
      self.utility_fee_frequency = previous_utility_fee_frequency
      update!(is_representative_tenant: true)
    end
  end

  # Check if the tenant is a representative for contract creation
  def is_representative_tenant?
    is_representative_tenant
  end

  # Get the effective room fee frequency to use
  def effective_room_fee_frequency
    room_fee_frequency || 1
  end

  # Get the effective utility fee frequency to use
  def effective_utility_fee_frequency
    utility_fee_frequency || 1
  end

  # Get payment frequency description for display
  def payment_frequency_description
    room_freq = effective_room_fee_frequency
    utility_freq = effective_utility_fee_frequency

    room_fee_text = room_freq == 1 ? "monthly" : "every #{room_freq} months"
    utility_fee_text = utility_freq == 1 ? "monthly" : "every #{utility_freq} months"

    "Room fees: #{room_fee_text}, Utility fees: #{utility_fee_text}"
  end

  private

  def set_default_payment_frequencies
    # Set default frequencies if they're nil
    self.room_fee_frequency ||= 1
    self.utility_fee_frequency ||= 1
  end

  def end_date_after_start_date
    if end_date <= start_date
      errors.add(:end_date, "must be after the start date")
    end
  end

  def only_one_representative_per_room
    other_representatives = room.room_assignments
                              .where(active: true, is_representative_tenant: true)
                              .where.not(id: id)

    if other_representatives.exists?
      errors.add(:is_representative_tenant, "There can only be one representative tenant per room")
    end
  end

  def ensure_only_representative_has_deposit
    if !is_representative_tenant? && deposit_amount.present? && deposit_amount > 0
      self.deposit_amount = nil
    end
  end

  def update_room_status
    if active?
      room.update(status: "occupied")
    elsif room.room_assignments.where(active: true).where.not(id: id).empty?
      room.update(status: "available")
    end
  end
end
