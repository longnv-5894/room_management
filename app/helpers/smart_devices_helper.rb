module SmartDevicesHelper
  def device_type_label(type)
    case type
    when 'fingerprint_lock'
      content_tag(:span, 'Khóa vân tay', class: 'badge bg-primary')
    when 'smart_lock'
      content_tag(:span, 'Khóa thông minh', class: 'badge bg-success')
    when 'camera'
      content_tag(:span, 'Camera', class: 'badge bg-info')
    when 'light'
      content_tag(:span, 'Đèn', class: 'badge bg-warning')
    when 'switch'
      content_tag(:span, 'Công tắc', class: 'badge bg-secondary')
    else
      content_tag(:span, 'Khác', class: 'badge bg-dark')
    end
  end

  def device_status_badge(status)
    if status == 'online'
      content_tag(:span, 'Trực tuyến', class: 'badge bg-success')
    else
      content_tag(:span, 'Ngoại tuyến', class: 'badge bg-danger')
    end
  end
end
