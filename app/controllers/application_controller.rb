class ApplicationController < ActionController::Base
  # Allow all browsers to access the application
  # Previously: allow_browser versions: :modern
  
  include SessionsHelper
  
  before_action :set_locale
  
  private
  
  def set_locale
    I18n.locale = session[:locale] || I18n.default_locale
  end
  
  def require_login
    unless session[:user_id]
      flash[:danger] = t('auth.login_required') 
      redirect_to login_path
      return false
    end
  end
end
