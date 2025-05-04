class ContractsController < ApplicationController
  before_action :require_login
  before_action :set_contract, only: [:show, :edit, :update, :destroy, :download, :generate_pdf]

  def index
    @contracts = Contract.includes(room_assignment: [:room, :tenant]).all
  end

  def show
  end

  def new
    @contract = Contract.new

    # Only load room assignments with representative tenants
    @room_assignments = RoomAssignment.includes(:room, :tenant)
                                     .where(active: true, is_representative_tenant: true)
  end

  def create
    @contract = Contract.new(contract_params)

    if @contract.save
      redirect_to @contract, notice: 'Contract was successfully created.'
    else
      @room_assignments = RoomAssignment.includes(:room, :tenant)
                                       .where(active: true, is_representative_tenant: true)
      render :new
    end
  end

  def edit
    @room_assignments = RoomAssignment.includes(:room, :tenant)
                                     .where(active: true, is_representative_tenant: true)
  end

  def update
    if @contract.update(contract_params)
      redirect_to @contract, notice: 'Contract was successfully updated.'
    else
      @room_assignments = RoomAssignment.includes(:room, :tenant)
                                       .where(active: true, is_representative_tenant: true)
      render :edit
    end
  end

  def destroy
    @contract.destroy
    redirect_to contracts_path, notice: 'Contract was successfully deleted.'
  end

  def download
    if @contract.document.attached?
      redirect_to url_for(@contract.document)
    else
      redirect_to @contract, alert: 'No document attached to this contract.'
    end
  end

  def generate_pdf
    if @contract.generate_html_contract
      redirect_to @contract, notice: t('contracts.generate_success')
    else
      redirect_to @contract, alert: t('contracts.template_not_found')
    end
  end

  def room_assignment_details
    room_assignment = RoomAssignment.includes(:room).find(params[:id])

    render json: {
      rent_amount: room_assignment.room.monthly_rent,
      deposit_amount: room_assignment.deposit_amount,
      start_date: room_assignment.start_date,
      tenant_name: room_assignment.tenant.name
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Room assignment not found" }, status: :not_found
  end

  private

  def set_contract
    @contract = Contract.find(params[:id])
  end

  def contract_params
    params.require(:contract).permit(
      :room_assignment_id, :contract_number, :start_date, :end_date,
      :rent_amount, :deposit_amount, :payment_due_day, :status, :document
    )
  end

  def require_login
    unless session[:user_id]
      flash[:danger] = t('auth.login_required')
      redirect_to login_path
    end
  end
end
