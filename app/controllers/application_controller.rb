class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  include SessionsHelper
  
  before_action :set_locale
  
  private
  
  def set_locale
    I18n.locale = session[:locale] || I18n.default_locale
  end
end
