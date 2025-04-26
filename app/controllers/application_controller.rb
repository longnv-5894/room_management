class ApplicationController < ActionController::Base
  # Allow all browsers to access the application
  # Previously: allow_browser versions: :modern
  
  include SessionsHelper
  
  before_action :set_locale
  
  private
  
  def set_locale
    I18n.locale = session[:locale] || I18n.default_locale
  end
end
