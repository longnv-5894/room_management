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
  scope :active, -> { where(status: "active") }
  scope :draft, -> { where(status: "draft") }
  scope :expired, -> { where(status: "expired") }
  scope :terminated, -> { where(status: "terminated") }

  # Generate contract number
  before_validation :generate_contract_number, on: :create, if: -> { contract_number.blank? }

  # Generate contract using the HTML template and convert to PDF
  def generate_pdf
    require "wicked_pdf"

    # Format currency amounts with thousands separators
    formatted_rent = number_with_delimiter(rent_amount || 0)
    formatted_deposit = number_with_delimiter(deposit_amount || 0)

    # Get payment schedule information directly from room_assignment
    room_payment_frequency = room_assignment.effective_room_fee_frequency
    utility_payment_frequency = room_assignment.effective_utility_fee_frequency

    # Create payment schedule text
    room_payment_text = room_payment_frequency == 1 ? "hàng tháng" : "mỗi #{room_payment_frequency} tháng"
    utility_payment_text = utility_payment_frequency == 1 ? "hàng tháng" : "mỗi #{utility_payment_frequency} tháng"

    # Get current utility prices
    current_price = UtilityPrice.current
    electricity_price = number_with_delimiter(current_price&.electricity_unit_price || 4000)
    water_price = number_with_delimiter(current_price&.water_unit_price || 30000)
    service_fee = number_with_delimiter(current_price&.service_charge || 200000)

    # Get co-tenants information (all active tenants in the same room except the representative tenant)
    co_tenants = []
    room.room_assignments.where(active: true).where.not(id: room_assignment.id).each do |assignment|
      co_tenants << {
        name: assignment.tenant.name,
        id_number: assignment.tenant.id_number,
        phone: assignment.tenant.phone,
        permanent_address: assignment.tenant.permanent_address,
        id_issue_date: assignment.tenant.id_issue_date,
        id_issue_place: assignment.tenant.id_issue_place
      }
    end

    # Create a hash of data to be inserted into the template
    data = {
      contract_number: contract_number,
      ngay_lam_hop_dong: Date.today.strftime("%d/%m/%Y"),
      today: Date.today,

      # Bên cho thuê (Landlord info from building)
      ten_chu_nha: room.building.user.name || room.building.name,
      sdt_chu_nha: room.building.user.phone || "N/A",
      dia_chi_chu_nha: room.building.address || "N/A",

      # Bên thuê (Tenant info) - Representative tenant
      ten_nguoi_thue: tenant.name,
      cmnd_nguoi_thue: tenant.id_number || "N/A",
      ngay_cap_cmnd: tenant.id_issue_date&.strftime("%d/%m/%Y") || "N/A",
      noi_cap_cmnd: tenant.id_issue_place || "N/A",
      sdt_nguoi_thue: tenant.phone || "N/A",
      dia_chi_nguoi_thue: tenant.permanent_address || "N/A",

      # Co-tenants information
      co_tenants: co_tenants,

      # Thông tin phòng (Room info)
      so_phong: room.number,
      ten_toa_nha: room.building.name,
      dia_chi_phong: room.building.address,
      dien_tich: room.area,

      # Thời hạn hợp đồng (Contract term)
      ngay_bat_dau: start_date.strftime("%d/%m/%Y"),
      ngay_ket_thuc: end_date.strftime("%d/%m/%Y"),
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
      utility_payment_text: utility_payment_text,

      # Utility rates
      electricity_price: electricity_price,
      water_price: water_price,
      service_fee: service_fee
    }

    begin
      # Get the template content - try different path methods to find the template
      template_path = nil
      possible_paths = [
        Rails.root.join("app", "views", "contracts", "templates", "rental_agreement.html.erb"),
        Rails.root.join("app/views/contracts/templates/rental_agreement.html.erb"),
        File.join(Rails.root, "app", "views", "contracts", "templates", "rental_agreement.html.erb")
      ]

      # Try to find the template at one of the possible paths
      possible_paths.each do |path|
        if File.exist?(path)
          template_path = path
          break
        end
      end

      # If template path is still nil, log an error
      unless template_path
        Rails.logger.error "Template not found at any of these locations: #{possible_paths.join(', ')}"
        return nil
      end

      # Read the template content
      template_content = File.read(template_path)

      # Create a renderer with the template
      renderer = ERB.new(template_content)

      # Bind the data to the template
      html_content = renderer.result(OpenStruct.new(data).instance_eval { binding })

      # Setup WickedPDF and return the PDF data
      WickedPdf.new.pdf_from_string(
        html_content,
        page_size: "A4",
        margin: {
          top: 20,
          bottom: 20,
          left: 30,
          right: 20
        },
        encoding: "UTF-8",
        footer: { right: "[page] of [topage]" }
      )
    rescue => e
      Rails.logger.error "Error generating contract: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
  end

  # Legacy method that attaches the PDF to the contract record
  # Kept for backward compatibility
  def generate_html_contract
    require "tempfile"

    pdf = generate_pdf
    return false unless pdf

    # Create a tempfile for the PDF
    pdf_file = Tempfile.new([ "contract", ".pdf" ])
    pdf_file.binmode
    pdf_file.write(pdf)
    pdf_file.close

    # Attach the generated document to the contract
    self.document.attach(
      io: File.open(pdf_file.path),
      filename: "hop_dong_thue_nha_#{contract_number}.pdf",
      content_type: "application/pdf"
    )

    self.save
    self.document.attached?
  ensure
    # Clean up temporary files
    pdf_file.unlink if pdf_file && pdf_file.respond_to?(:unlink)
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
    date_part = Date.today.strftime("%Y%m%d")
    last_contract = Contract.where("contract_number LIKE ?", "CTR-#{date_part}-%").order(:contract_number).last

    if last_contract.nil?
      number = 1
    else
      number = last_contract.contract_number.split("-").last.to_i + 1
    end

    self.contract_number = "CTR-#{date_part}-#{number.to_s.rjust(3, '0')}"
  end

  def number_to_words(number)
    # Format numbers in Vietnamese style for the contract
    # Example: 2.500.000đ (hai triệu năm trăm nghìn đồng)

    # Convert number to Vietnamese words
    vietnamese_words = vietnamese_number_to_words(number.to_i)

    # Return in the format shown in the screenshot
    "#{vietnamese_words} đồng"
  end

  # If we need formatted numbers with thousands separators in the future
  # we can use this method
  def format_number_with_delimiters(number)
    # Convert number to string and split integer and decimal parts
    num_str = number.to_s
    int_part, dec_part = num_str.split(".")

    # Format the integer part with dots as thousand separators
    formatted_int = int_part.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse

    # Combine with decimal part if present, using comma as decimal separator
    dec_part ? "#{formatted_int},#{dec_part}" : formatted_int
  end

  # Helper method to convert numbers to Vietnamese words
  def vietnamese_number_to_words(number)
    return "không" if number == 0

    # Vietnamese word arrays
    digits = [ "", "một", "hai", "ba", "bốn", "năm", "sáu", "bảy", "tám", "chín" ]
    groups = [ "", "nghìn", "triệu", "tỷ", "nghìn tỷ", "triệu tỷ" ]

    # Process number in groups of 3 digits
    str = number.to_s
    groups_of_3 = []

    # Ensure the string length is a multiple of 3 by padding with zeros
    while str.length % 3 != 0
      str = "0" + str
    end

    # Split into groups of 3
    0.step(str.length - 1, 3) do |i|
      groups_of_3 << str[i, 3].to_i
    end

    # Process each group
    result = ""
    groups_of_3.each_with_index do |group, index|
      # Skip if the group is 000
      next if group == 0

      group_index = groups_of_3.length - index - 1

      # Process each group of 3 digits
      hundreds = group / 100
      tens = (group % 100) / 10
      ones = group % 10

      group_result = ""

      # Hundreds
      if hundreds > 0
        group_result += "#{digits[hundreds]} trăm "
      end

      # Tens and ones
      if tens > 0
        if tens == 1
          group_result += "mười "
          if ones > 0
            if ones == 5
              group_result += "lăm"
            elsif ones == 1
              group_result += "một"
            else
              group_result += digits[ones]
            end
          end
        else
          group_result += "#{digits[tens]} mươi "
          if ones > 0
            if ones == 1
              group_result += "mốt"
            elsif ones == 5
              group_result += "lăm"
            else
              group_result += digits[ones]
            end
          end
        end
      elsif ones > 0
        if hundreds > 0
          # If there's a hundred but no tens, we need to add "lẻ"
          group_result += "lẻ "
        end
        group_result += digits[ones]
      end

      # Add the group name if not empty
      if !group_result.empty?
        group_result = "#{group_result.strip} #{groups[group_index]}".strip
        result = result.empty? ? group_result : "#{result} #{group_result}"
      end
    end

    result.strip
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
  end
end
