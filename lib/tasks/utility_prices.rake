namespace :utility_prices do
  desc "Xóa tất cả dữ liệu từ bảng utility_prices"
  task clear: :environment do
    puts "Đang xóa tất cả dữ liệu từ bảng utility_prices..."
    count = UtilityPrice.count
    UtilityPrice.delete_all
    puts "Đã xóa #{count} bản ghi từ bảng utility_prices."
  end
end
