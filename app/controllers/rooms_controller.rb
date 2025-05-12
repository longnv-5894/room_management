class RoomsController < ApplicationController
  before_action :require_login
  before_action :set_room, only: [ :show, :edit, :update, :destroy ]
  before_action :set_building, only: [ :index, :new, :create ]

  def index
    # Check if we're viewing rooms for a specific building
    if @building && !params[:ignore_building_context]
      @rooms = @building.rooms.order(:number)
      render "building_rooms"
    else
      @search_query = params[:search]
      @building_filter = params[:building_id]
      @status_filter = params[:status]

      # Start with base query
      query = Room.includes(:building)

      # Apply search filter if present
      if @search_query.present?
        query = query.where("LOWER(number) LIKE ?", "%#{@search_query.downcase}%")
      end

      # Apply building filter if present
      if @building_filter.present?
        query = query.where(building_id: @building_filter)
      end

      # Apply status filter if present
      if @status_filter.present?
        query = query.where(status: @status_filter)
      end

      @rooms = query.order("buildings.name", :number)
    end
  end

  def show
    @current_tenants = @room.current_tenants
    @latest_reading = @room.utility_readings.order(reading_date: :desc).first
    @room_assignments = @room.room_assignments.where(active: true).includes(:tenant)
    @representative_tenant = @room_assignments.find_by(is_representative_tenant: true)&.tenant
  end

  def new
    @room = @building ? @building.rooms.build : Room.new
  end

  def create
    if @building
      @room = @building.rooms.build(room_params)
    else
      @room = Room.new(room_params)
    end

    if @room.save
      flash[:success] = t("rooms.create_success")
      if @building
        redirect_to building_path(@building)
      else
        redirect_to @room
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @room.update(room_params)
      flash[:success] = t("rooms.update_success")
      redirect_to @room
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @room.room_assignments.exists?
      flash[:danger] = t("rooms.cannot_delete_with_assignments")
      redirect_to @room.building || rooms_url
    else
      building = @room.building
      @room.destroy
      flash[:success] = t("rooms.delete_success")
      redirect_to building || rooms_url
    end
  end

  private

  def set_room
    @room = Room.find(params[:id])
  end

  def set_building
    @building = Building.find(params[:building_id]) if params[:building_id]
  end

  def room_params
    params.require(:room).permit(:number, :floor, :area, :status, :building_id)
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t("auth.login_required")
      redirect_to login_path
    end
  end
end
