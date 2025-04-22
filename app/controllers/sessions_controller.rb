class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(email: params[:session][:email].downcase)
    if user && user.authenticate(params[:session][:password])
      # Log the user in and redirect to the user's show page
      session[:user_id] = user.id
      flash[:success] = t('auth.login_success')
      redirect_to root_path  # Redirect to homepage or dashboard
    else
      # Create an error message
      flash.now[:danger] = t('auth.login_failed')
      render 'new', status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    @current_user = nil
    flash[:success] = t('auth.logout_success')
    redirect_to login_path
  end
end
