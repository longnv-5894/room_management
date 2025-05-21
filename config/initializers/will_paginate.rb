# Configure will_paginate to use Bootstrap styling by default
if defined?(WillPaginate)
  require "will_paginate/view_helpers/action_view"

  class BootstrapPaginationRenderer < WillPaginate::ActionView::LinkRenderer
    def html_container(html)
      tag(:ul, html, class: "pagination")
    end

    def page_number(page)
      if page == current_page
        tag(:li, tag(:span, page, class: "page-link"), class: "page-item active")
      else
        tag(:li, link(page, page, class: "page-link", rel: rel_value(page)), class: "page-item")
      end
    end

    def previous_or_next_page(page, text, classname, extra_param = nil)
      if page
        tag(:li, link(text, page, class: "page-link"), class: "page-item")
      else
        tag(:li, tag(:span, text, class: "page-link"), class: "page-item disabled")
      end
    end

    def gap
      tag(:li, tag(:span, "&hellip;", class: "page-link"), class: "page-item disabled")
    end
  end
end
