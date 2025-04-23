module BillsHelper
  def bill_status_color(status)
    case status
    when 'paid'
      'success'
    when 'partial'
      'warning'
    when 'unpaid'
      'danger'
    else
      'secondary'
    end
  end
end
