class RoomsController < ApplicationController
  before_action :require_login
  before_action :set_room, only: [:show, :edit, :update, :destroy]

  def index
    @rooms = Room.all
  end

  def show
    @current_tenants = @room.current_tenants
    @latest_reading = @room.utility_readings.order(reading_date: :desc).first
  end

  def new
    @room = Room.new
  end

  def create
    @room = Room.new(room_params)

    if @room.save
      flash[:success] = t('rooms.create_success')
      redirect_to @room
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @room.update(room_params)
      flash[:success] = t('rooms.update_success')
      redirect_to @room
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @room.room_assignments.exists?
      flash[:danger] = t('rooms.cannot_delete_with_assignments')
      redirect_to rooms_url
    else
      @room.destroy
      flash[:success] = t('rooms.delete_success')
      redirect_to rooms_url
    end
  end

  private

  def set_room
    @room = Room.find(params[:id])
  end

  def room_params
    params.require(:room).permit(:number, :floor, :area, :monthly_rent, :status)
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t('auth.login_required')
      redirect_to login_path
    end
  end
end
