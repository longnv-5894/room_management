class UsersController < ApplicationController
  before_action :require_login, only: [:show, :edit, :update]
  before_action :set_user, only: [:show, :edit, :update]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      session[:user_id] = @user.id
      flash[:success] = "Account successfully created!"
      redirect_to root_path
    else
      flash.now[:danger] = "There was a problem creating your account."
      render 'new', status: :unprocessable_entity
    end
  end
  
  def show
    # Profile page
  end
  
  def edit
    # Edit profile page
  end
  
  def update
    if @user.update(user_params)
      flash[:success] = t('users.update_success')
      redirect_to profile_path
    else
      flash.now[:danger] = t('users.update_error')
      render 'edit', status: :unprocessable_entity
    end
  end

  private
  
  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(
      :email, :password, :password_confirmation, :name,
      :phone, :address, :gender, :date_of_birth, :id_number,
      :profile_image
    )
  end
  
  def require_login
    unless session[:user_id]
      flash[:danger] = t('auth.login_required')
      redirect_to login_path
    end
  end
end
