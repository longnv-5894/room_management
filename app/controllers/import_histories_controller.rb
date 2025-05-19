class ImportHistoriesController < ApplicationController
  before_action :require_login 
  before_action :set_import_history, only: [:show, :revert, :download]
  before_action :set_building, only: [:index]

  def index
    @import_histories = @building.import_histories.order(import_date: :desc)
  end

  def show
    # Hiển thị chi tiết về lần import
    @building = @import_history.building
  end

  def revert
    # Thực hiện revert dữ liệu từ lần import này
    respond_to do |format|
      if @import_history.revert!
        format.html { redirect_to import_history_path(@import_history), notice: "Đã revert dữ liệu từ lần import này thành công" }
        format.json { render json: { status: "success", message: "Đã revert dữ liệu từ lần import này thành công" } }
      else
        format.html { redirect_to import_history_path(@import_history), alert: "Không thể revert dữ liệu: #{@import_history.errors.full_messages.join(', ')}" }
        format.json { render json: { status: "error", message: @import_history.errors.full_messages.join(', ') }, status: :unprocessable_entity }
      end
    end
  end

  def download
    # Kiểm tra xem file có tồn tại không
    if @import_history.file_path.present? && File.exist?(@import_history.file_path)
      # Tải file xuống
      send_file @import_history.file_path, disposition: 'attachment', filename: @import_history.file_name
    else
      redirect_to import_history_path(@import_history), alert: "File không tồn tại hoặc đã bị xóa"
    end
  end

  private

  def set_import_history
    @import_history = ImportHistory.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to buildings_path, alert: "Không tìm thấy lịch sử import"
  end

  def set_building
    @building = Building.find(params[:building_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to buildings_path, alert: "Không tìm thấy tòa nhà"
  end
end
