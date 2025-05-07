class Contract < ApplicationRecord
  belongs_to :room_assignment
  has_one :room, through: :room_assignment
  has_one :tenant, through: :room_assignment

  # Active Storage for document attachment
  has_one_attached :document

  # Validations
  validates :contract_number, presence: true, uniqueness: true
  validates :start_date, :end_date, presence: true
  validates :rent_amount, :deposit_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: { in: %w[draft active expired terminated] }

  validate :end_date_after_start_date, if: -> { end_date.present? && start_date.present? }
  validate :room_assignment_has_representative_tenant

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :draft, -> { where(status: 'draft') }
  scope :expired, -> { where(status: 'expired') }
  scope :terminated, -> { where(status: 'terminated') }

  # Generate contract number
  before_validation :generate_contract_number, on: :create, if: -> { contract_number.blank? }

  # Generate contract using the HTML template and convert to PDF
  def generate_html_contract
    require 'tempfile'
    require 'wicked_pdf'

    # Format currency amounts with thousands separators
    formatted_rent = number_with_delimiter(rent_amount || 0)
    formatted_deposit = number_with_delimiter(deposit_amount || 0)

    # Get payment schedule information directly from room_assignment
    room_payment_frequency = room_assignment.effective_room_fee_frequency
    utility_payment_frequency = room_assignment.effective_utility_fee_frequency
    
    # Create payment schedule text
    room_payment_text = room_payment_frequency == 1 ? "hàng tháng" : "mỗi #{room_payment_frequency} tháng"
    utility_payment_text = utility_payment_frequency == 1 ? "hàng tháng" : "mỗi #{utility_payment_frequency} tháng"

    # Create a hash of data to be inserted into the template
    data = {
      contract_number: contract_number,
      ngay_lam_hop_dong: Date.today.strftime('%d/%m/%Y'),

      # Bên cho thuê (Landlord info from building)
      ten_chu_nha: room.building.user.name || room.building.name,
      sdt_chu_nha: room.building.user.phone || 'N/A',
      dia_chi_chu_nha: room.building.address || 'N/A',

      # Bên thuê (Tenant info)
      ten_nguoi_thue: tenant.name,
      cmnd_nguoi_thue: tenant.id_number || 'N/A',
      sdt_nguoi_thue: tenant.phone || 'N/A',
      dia_chi_nguoi_thue: "N/A", # No permanent address field available

      # Thông tin phòng (Room info)
      so_phong: room.number,
      ten_toa_nha: room.building.name,
      dia_chi_phong: room.building.address,
      dien_tich: room.area,

      # Thời hạn hợp đồng (Contract term)
      ngay_bat_dau: start_date.strftime('%d/%m/%Y'),
      ngay_ket_thuc: end_date.strftime('%d/%m/%Y'),
      start_date: start_date,
      end_date: end_date,

      # Giá thuê và đặt cọc (Rent and deposit)
      tien_thue: formatted_rent,
      tien_thue_bang_chu: number_to_words(rent_amount || 0),
      tien_coc: formatted_deposit,
      tien_coc_bang_chu: number_to_words(deposit_amount || 0),
      ngay_tra_tien: payment_due_day || 5,
      
      # Payment schedule information
      room_payment_frequency: room_payment_frequency,
      utility_payment_frequency: utility_payment_frequency,
      room_payment_text: room_payment_text,
      utility_payment_text: utility_payment_text
    }

    begin
      # Get the template content
      template_path = Rails.root.join('app', 'views', 'contracts', 'templates', 'rental_agreement.html.erb')
      template_content = File.read(template_path)

      # Create a renderer with the template
      renderer = ERB.new(template_content)

      # Bind the data to the template
      html_content = renderer.result(OpenStruct.new(data).instance_eval { binding })

      # Setup WickedPDF
      pdf = WickedPdf.new.pdf_from_string(
        html_content,
        page_size: 'A4',
        margin: { top: 10, bottom: 10, left: 10, right: 10 },
        encoding: 'UTF-8',
        footer: { right: '[page] of [topage]' }
      )

      # Create a tempfile for the PDF
      pdf_file = Tempfile.new(['contract', '.pdf'])
      pdf_file.binmode
      pdf_file.write(pdf)
      pdf_file.close

      # Attach the generated document to the contract
      self.document.attach(
        io: File.open(pdf_file.path),
        filename: "hop_dong_thue_nha_#{contract_number}.pdf",
        content_type: 'application/pdf'
      )

      self.save
    rescue => e
      Rails.logger.error "Error generating contract: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return false
    ensure
      # Clean up temporary files
      pdf_file.unlink if pdf_file && pdf_file.respond_to?(:unlink)
    end

    return self.document.attached?
  end

  private

  def room_assignment_has_representative_tenant
    unless room_assignment&.is_representative_tenant?
      errors.add(:room_assignment, "must be with a representative tenant")
    end
  end

  def end_date_after_start_date
    if end_date <= start_date
      errors.add(:end_date, "must be after the start date")
    end
  end

  def generate_contract_number
    date_part = Date.today.strftime('%Y%m%d')
    last_contract = Contract.where("contract_number LIKE ?", "CTR-#{date_part}-%").order(:contract_number).last

    if last_contract.nil?
      number = 1
    else
      number = last_contract.contract_number.split('-').last.to_i + 1
    end

    self.contract_number = "CTR-#{date_part}-#{number.to_s.rjust(3, '0')}"
  end

  def number_to_words(number)
    return 'không đồng' if number == 0

    # Vietnamese number to words conversion
    # This is a more comprehensive implementation for Vietnamese currency
    units = ['', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín']
    teens = ['', 'mười một', 'mười hai', 'mười ba', 'mười bốn', 'mười lăm', 'mười sáu', 'mười bảy', 'mười tám', 'mười chín']
    tens = ['', 'mười', 'hai mươi', 'ba mươi', 'bốn mươi', 'năm mươi', 'sáu mươi', 'bảy mươi', 'tám mươi', 'chín mươi']
    groups = ['', 'nghìn', 'triệu', 'tỷ', 'nghìn tỷ', 'triệu tỷ']

    # Special case for small numbers
    if number < 10
      return "#{units[number]} đồng"
    elsif number < 20
      return "#{teens[number - 10]} đồng"
    elsif number < 100
      unit = number % 10
      ten = number / 10
      unit_str = unit == 0 ? '' : " #{units[unit]}"
      return "#{tens[ten]}#{unit_str} đồng"
    end

    # For larger numbers, just return the numeric form for now
    # A complete implementation would be more complex
    return "#{number.to_s} đồng"
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
  end
end
