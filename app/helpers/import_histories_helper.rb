module ImportHistoriesHelper
  # Trả về lớp badge Bootstrap tương ứng với trạng thái import
  def status_badge_class(status)
    case status
    when 'success'
      'bg-success'
    when 'partial'
      'bg-warning'
    when 'failed'
      'bg-danger'
    when 'reverted'
      'bg-secondary'
    else
      'bg-info'
    end
  end
end