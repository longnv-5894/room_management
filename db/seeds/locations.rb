# Seed file for Vietnam location data
# This file contains comprehensive data for Vietnam administrative divisions with proper Vietnamese names

# Temporarily set locale to English for seeding to avoid translation errors
I18n.with_locale(:en) do
  # Helper method to create city and associated districts and wards
  def create_city_with_districts_and_wards(country, city_name, districts_data)
    puts "Creating city: #{city_name} (if it doesn't exist)"
    city = City.find_or_create_by!(name: city_name, country: country)
    
    districts_data.each do |district_name, wards|
      puts "  Creating district: #{district_name} (if it doesn't exist)"
      district = District.find_or_create_by!(name: district_name, city: city)
      
      if wards.present?
        puts "    Creating wards for #{district_name}"
        wards.each do |ward_name|
          Ward.find_or_create_by!(name: ward_name, district: district)
        end
      end
    end
    
    return city
  end

  # Create Vietnam as a country if it doesn't exist
  puts "Creating country: Vietnam (if it doesn't exist)"
  vietnam = Country.find_by(code: "VN")
  if vietnam.nil?
    vietnam = Country.create!(name: "Việt Nam", code: "VN")
  else
    # Update the name if it's not in Vietnamese
    vietnam.update(name: "Việt Nam") unless vietnam.name == "Việt Nam"
    puts "Found existing country: #{vietnam.name}"
  end

  # NORTHERN VIETNAM - Major Cities

  # 1. Hanoi - Capital city with proper Vietnamese names
  hanoi_districts = {
    "Ba Đình" => ["Phúc Xá", "Trúc Bạch", "Vĩnh Phúc", "Cống Vị", "Liễu Giai", "Nguyễn Trung Trực", "Quán Thánh", "Ngọc Hà", "Điện Biên", "Đội Cấn", "Ngọc Khánh", "Kim Mã", "Giảng Võ", "Thành Công"],
    "Hoàn Kiếm" => ["Phúc Tân", "Đồng Xuân", "Hàng Mã", "Hàng Buồm", "Hàng Đào", "Hàng Bồ", "Cửa Đông", "Lý Thái Tổ", "Hàng Bạc", "Hàng Gai", "Chương Dương", "Hàng Trống", "Trần Hưng Đạo", "Phan Chu Trinh", "Hàng Bông"],
    "Hai Bà Trưng" => ["Nguyễn Du", "Bùi Thị Xuân", "Ngô Thì Nhậm", "Lê Đại Hành", "Đồng Nhân", "Phạm Đình Hổ", "Bạch Đằng", "Thanh Nhàn", "Cầu Dền", "Bách Khoa", "Quỳnh Lôi", "Vĩnh Tuy", "Đồng Tâm", "Trương Định", "Minh Khai", "Định Công"],
    "Đống Đa" => ["Cát Linh", "Văn Miếu", "Quốc Tử Giám", "Láng Thượng", "Ô Chợ Dừa", "Văn Chương", "Kim Liên", "Phương Liên", "Nam Đồng", "Quang Trung", "Trung Phụng", "Hàng Bột", "Khương Thượng", "Thổ Quan", "Trung Liệt", "Phương Mai", "Khâm Thiên"],
    "Cầu Giấy" => ["Nghĩa Đô", "Quan Hoa", "Dịch Vọng", "Dịch Vọng Hậu", "Mai Dịch", "Yên Hòa", "Trung Hòa"],
    "Long Biên" => ["Thạch Bàn", "Long Biên", "Phúc Lợi", "Sài Đồng", "Bồ Đề", "Cự Khối", "Việt Hưng", "Gia Thụy", "Ngọc Lâm", "Phúc Đồng", "Đức Giang", "Thượng Thanh"],
    "Tây Hồ" => ["Bưởi", "Thụy Khuê", "Yên Phụ", "Tứ Liên", "Quảng An", "Xuân La", "Phú Thượng", "Nhật Tân"],
    "Hà Đông" => ["Văn Quán", "Yên Nghĩa", "Phú La", "Kiến Hưng", "Phú Lãm", "Phú La", "Hà Cầu", "Yên Nghĩa", "Kiến Hưng", "Dương Nội", "La Khê", "Đồng Mai", "Biên Giang"],
    "Hoàng Mai" => ["Thanh Trì", "Định Công", "Đại Kim", "Hoàng Văn Thụ", "Thịnh Liệt", "Trần Phú", "Hoàng Liệt", "Yên Sở", "Mai Động", "Giáp Bát", "Tân Mai", "Tương Mai", "Vĩnh Hưng"]
  }

  hanoi = create_city_with_districts_and_wards(vietnam, "Hà Nội", hanoi_districts)

  # 2. Ho Chi Minh City (HCMC) - Economic hub with proper Vietnamese names
  hcmc_districts = {
    "Quận 1" => ["Bến Nghé", "Bến Thành", "Cầu Kho", "Cầu Ông Lãnh", "Cô Giang", "Đa Kao", "Nguyễn Cư Trinh", "Nguyễn Thái Bình", "Phạm Ngũ Lão", "Tân Định"],
    "Quận 2" => ["An Khánh", "An Lợi Đông", "An Phú", "Bình An", "Bình Khánh", "Bình Trưng Đông", "Bình Trưng Tây", "Cát Lái", "Thạnh Mỹ Lợi", "Thủ Thiêm"],
    "Quận 3" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 6", "Phường 7", "Phường 8", "Phường 9", "Phường 10", "Phường 11", "Phường 12", "Phường 13", "Phường 14"],
    "Quận 4" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 6", "Phường 8", "Phường 9", "Phường 10", "Phường 13", "Phường 14", "Phường 15", "Phường 16", "Phường 18"],
    "Quận 5" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 6", "Phường 7", "Phường 8", "Phường 9", "Phường 10", "Phường 11", "Phường 12", "Phường 13", "Phường 14", "Phường 15"],
    "Quận 6" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 6", "Phường 7", "Phường 8", "Phường 9", "Phường 10", "Phường 11", "Phường 12", "Phường 13", "Phường 14"],
    "Quận 7" => ["Bình Thuận", "Phú Mỹ", "Phú Thuận", "Tân Hưng", "Tân Kiểng", "Tân Phong", "Tân Phú", "Tân Quy", "Tân Thuận Đông", "Tân Thuận Tây"],
    "Quận 8" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 6", "Phường 7", "Phường 8", "Phường 9", "Phường 10", "Phường 11", "Phường 12", "Phường 13", "Phường 14", "Phường 15", "Phường 16"],
    "Quận 9" => ["Hiệp Phú", "Long Bình", "Long Phước", "Long Thạnh Mỹ", "Long Trường", "Phước Bình", "Phước Long A", "Phước Long B", "Tăng Nhơn Phú A", "Tăng Nhơn Phú B", "Trường Thạnh"],
    "Quận 10" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 6", "Phường 7", "Phường 8", "Phường 9", "Phường 10", "Phường 11", "Phường 12", "Phường 13", "Phường 14", "Phường 15"],
    "Quận 11" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 6", "Phường 7", "Phường 8", "Phường 9", "Phường 10", "Phường 11", "Phường 12", "Phường 13", "Phường 14", "Phường 15", "Phường 16"],
    "Quận 12" => ["An Phú Đông", "Đông Hưng Thuận", "Hiệp Thành", "Tân Chánh Hiệp", "Tân Hưng Thuận", "Tân Thới Hiệp", "Tân Thới Nhất", "Thạnh Lộc", "Thạnh Xuân", "Thới An", "Trung Mỹ Tây"],
    "Bình Tân" => ["An Lạc", "An Lạc A", "Bình Hưng Hòa", "Bình Hưng Hòa A", "Bình Hưng Hòa B", "Bình Trị Đông", "Bình Trị Đông A", "Bình Trị Đông B", "Tân Tạo", "Tân Tạo A"],
    "Bình Thạnh" => ["Phường 1", "Phường 2", "Phường 3", "Phường 5", "Phường 6", "Phường 7", "Phường 11", "Phường 12", "Phường 13", "Phường 14", "Phường 15", "Phường 17", "Phường 19", "Phường 21", "Phường 22", "Phường 24", "Phường 25", "Phường 26", "Phường 27", "Phường 28"],
    "Phú Nhuận" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 7", "Phường 8", "Phường 9", "Phường 10", "Phường 11", "Phường 13", "Phường 14", "Phường 15", "Phường 17"],
    "Tân Bình" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 6", "Phường 7", "Phường 8", "Phường 9", "Phường 10", "Phường 11", "Phường 12", "Phường 13", "Phường 14", "Phường 15"],
    "Tân Phú" => ["Hiệp Tân", "Hòa Thạnh", "Phú Thạnh", "Phú Thọ Hòa", "Phú Trung", "Sơn Kỳ", "Tân Quý", "Tân Sơn Nhì", "Tân Thành", "Tân Thới Hòa", "Tây Thạnh"],
    "Thủ Đức" => ["Bình Chiểu", "Bình Thọ", "Hiệp Bình Chánh", "Hiệp Bình Phước", "Linh Chiểu", "Linh Đông", "Linh Tây", "Linh Trung", "Linh Xuân", "Tam Bình", "Tam Phú", "Trường Thọ"]
  }

  hcmc = create_city_with_districts_and_wards(vietnam, "Thành phố Hồ Chí Minh", hcmc_districts)

  # 3. Da Nang - Central major city
  danang_districts = {
    "Hải Châu" => ["Hải Châu I", "Hải Châu II", "Thạch Thang", "Thanh Bình", "Thuận Phước", "Bình Hiên", "Bình Thuận", "Hòa Cường Bắc", "Hòa Cường Nam", "Hòa Thuận Đông", "Hòa Thuận Tây", "Nam Dương", "Phước Ninh"],
    "Thanh Khê" => ["An Khê", "Chính Gián", "Hòa Khê", "Tam Thuận", "Tân Chính", "Thanh Khê Đông", "Thanh Khê Tây", "Thạc Gián", "Vĩnh Trung", "Xuân Hà"],
    "Sơn Trà" => ["An Hải Bắc", "An Hải Đông", "An Hải Tây", "Mân Thái", "Nại Hiên Đông", "Phước Mỹ", "Thọ Quang"],
    "Ngũ Hành Sơn" => ["Hòa Hải", "Hòa Quý", "Khuê Mỹ", "Mỹ An"],
    "Liên Chiểu" => ["Hòa Hiệp Bắc", "Hòa Hiệp Nam", "Hòa Khánh Bắc", "Hòa Khánh Nam", "Hòa Minh"],
    "Cẩm Lệ" => ["Hòa An", "Hòa Phát", "Hòa Thọ Đông", "Hòa Thọ Tây", "Hòa Xuân", "Khuê Trung"]
  }

  danang = create_city_with_districts_and_wards(vietnam, "Đà Nẵng", danang_districts)

  # 4. Can Tho - Mekong Delta major city
  cantho_districts = {
    "Ninh Kiều" => ["An Bình", "An Cư", "An Hòa", "An Khánh", "An Lạc", "An Nghiệp", "An Phú", "Cái Khế", "Hưng Lợi", "Tân An", "Thới Bình", "Xuân Khánh"],
    "Ô Môn" => ["Châu Văn Liêm", "Long Hưng", "Phước Thới", "Thới An", "Thới Hòa", "Thới Long", "Trường Lạc"],
    "Bình Thủy" => ["An Thới", "Bình Thủy", "Bùi Hữu Nghĩa", "Long Hòa", "Long Tuyền", "Thốt Nốt", "Trà An", "Trà Nóc"],
    "Cái Răng" => ["Ba Láng", "Hưng Phú", "Lê Bình", "Phú Thứ", "Tân Phú", "Thường Thạnh"],
    "Thốt Nốt" => ["Tân Hưng", "Tân Lộc", "Thới Thuận", "Thuận An", "Thuận Hưng", "Trung Hưng", "Trung Kiên", "Trung Nhứt"]
  }

  cantho = create_city_with_districts_and_wards(vietnam, "Cần Thơ", cantho_districts)

  # 5. Hai Phong - Northern major port city
  haiphong_districts = {
    "Hồng Bàng" => ["Hoàng Văn Thụ", "Minh Khai", "Hạ Lý", "Phan Bội Châu", "Phạm Hồng Thái", "Quang Trung", "Đông Khê", "Cầu Đất", "Thượng Lý"],
    "Ngô Quyền" => ["Máy Chai", "Máy Tơ", "Vạn Mỹ", "Cầu Tre", "Lạch Tray", "Đổng Quốc Bình", "Lê Lợi", "Đằng Giang", "Lạc Viên", "Gia Viên", "Đông Hải", "Cầu Đất"],
    "Lê Chân" => ["An Biên", "Cát Dài", "Đông Hải", "Hàng Kênh", "Lam Sơn", "Nghĩa Xá", "Niệm Nghĩa", "Trại Chuối"],
    "Hải An" => ["Đằng Hải", "Đằng Lâm", "Đông Hải 1", "Đông Hải 2", "Nam Hải", "Thành Tô", "Tràng Cát"],
    "Kiến An" => ["Bắc Sơn", "Đồng Hòa", "Nam Sơn", "Ngọc Sơn", "Phù Liễn", "Trần Thành Ngọ", "Tràng Minh"],
    "Đồ Sơn" => ["Bàng La", "Hợp Đức", "Minh Đức", "Ngọc Hải", "Ngọc Xuyên", "Vạn Hương", "Vạn Sơn"]
  }

  haiphong = create_city_with_districts_and_wards(vietnam, "Hải Phòng", haiphong_districts)

  # OTHER PROVINCES - Adding more authentic Vietnamese cities/provinces

  # Northern provinces
  create_city_with_districts_and_wards(vietnam, "Bắc Giang", {"Thành phố Bắc Giang" => ["Hoàng Văn Thụ", "Lê Lợi", "Mỹ Độ", "Ngô Quyền", "Trần Nguyên Hãn", "Trần Phú", "Xương Giang"]})
  create_city_with_districts_and_wards(vietnam, "Bắc Ninh", {"Thành phố Bắc Ninh" => ["Đại Phúc", "Kinh Bắc", "Ninh Xá", "Suối Hoa", "Tiền An", "Vệ An", "Võ Cường", "Vạn An"]})
  create_city_with_districts_and_wards(vietnam, "Hải Dương", {"Thành phố Hải Dương" => ["Ái Quốc", "Bình Hàn", "Cẩm Thượng", "Hải Tân", "Ngọc Châu", "Nhị Châu", "Phạm Ngũ Lão", "Quang Trung", "Tân Bình", "Thanh Bình", "Trần Hưng Đạo", "Trần Phú", "Tứ Minh"]})
  create_city_with_districts_and_wards(vietnam, "Hưng Yên", {"Thành phố Hưng Yên" => ["An Tảo", "Hiến Nam", "Hồng Châu", "Lam Sơn", "Lê Lợi", "Minh Khai", "Quang Trung"]})
  create_city_with_districts_and_wards(vietnam, "Nam Định", {"Thành phố Nam Định" => ["Bà Triệu", "Cửa Bắc", "Cửa Nam", "Hạ Long", "Lộc Hạ", "Lộc Vượng", "Năng Tĩnh", "Ngô Quyền", "Nguyễn Du", "Phan Đình Phùng", "Quang Trung", "Thống Nhất", "Trần Đăng Ninh", "Trần Hưng Đạo", "Trần Quang Khải", "Trần Tế Xương", "Trường Thi", "Văn Miếu", "Vị Hoàng", "Vị Xuyên"]})
  create_city_with_districts_and_wards(vietnam, "Ninh Bình", {"Thành phố Ninh Bình" => ["Bích Đào", "Đông Thành", "Nam Bình", "Nam Thành", "Ninh Khánh", "Ninh Phong", "Ninh Sơn", "Phúc Thành", "Tân Thành", "Thanh Bình", "Vân Giang"]})
  create_city_with_districts_and_wards(vietnam, "Thái Bình", {"Thành phố Thái Bình" => ["Bồ Xuyên", "Đề Thám", "Hoàng Diệu", "Kỳ Bá", "Lê Hồng Phong", "Phú Khánh", "Quang Trung", "Tiền Phong", "Trần Hưng Đạo", "Trần Lãm"]})
  create_city_with_districts_and_wards(vietnam, "Vĩnh Phúc", {"Thành phố Vĩnh Yên" => ["Đống Đa", "Hội Hợp", "Khai Quang", "Liên Bảo", "Ngô Quyền", "Tích Sơn"], "Thành phố Phúc Yên" => ["Hùng Vương", "Nam Viêm", "Phúc Thắng", "Tiền Châu", "Trưng Nhị", "Trưng Trắc", "Xuân Hòa"]})

  # Central provinces
  create_city_with_districts_and_wards(vietnam, "Thừa Thiên Huế", {"Thành phố Huế" => ["An Cựu", "An Đông", "An Hòa", "An Tây", "Đông Ba", "Gia Hội", "Hương Long", "Hương Sơ", "Kim Long", "Phú Bình", "Phú Cát", "Phú Hậu", "Phú Hiệp", "Phú Hòa", "Phú Nhuận", "Phú Thuận", "Phước Vĩnh", "Phường Đúc", "Tây Lộc", "Thuận Hòa", "Thuận Lộc", "Thuận Thành", "Trường An", "Vĩnh Ninh", "Xuân Phú"]})
  create_city_with_districts_and_wards(vietnam, "Khánh Hòa", {"Thành phố Nha Trang" => ["Lộc Thọ", "Ngọc Hiệp", "Phước Hải", "Phước Hòa", "Phước Long", "Phước Tân", "Phước Tiến", "Phương Sài", "Phương Sơn", "Tân Lập", "Vạn Thạnh", "Vạn Thắng", "Vĩnh Hải", "Vĩnh Nguyên", "Vĩnh Phước", "Vĩnh Thọ", "Vĩnh Trường", "Xương Huân"]})
  create_city_with_districts_and_wards(vietnam, "Bình Định", {"Thành phố Quy Nhơn" => ["Bùi Thị Xuân", "Đống Đa", "Ghềnh Ráng", "Hải Cảng", "Lê Hồng Phong", "Lê Lợi", "Lý Thường Kiệt", "Ngô Mây", "Nguyễn Văn Cừ", "Nhơn Bình", "Nhơn Phú", "Quang Trung", "Thị Nại", "Trần Hưng Đạo", "Trần Phú", "Trần Quang Diệu"]})
  create_city_with_districts_and_wards(vietnam, "Nghệ An", {"Thành phố Vinh" => ["Bến Thủy", "Cửa Nam", "Đội Cung", "Đông Vĩnh", "Hà Huy Tập", "Hồng Sơn", "Hưng Bình", "Hưng Dũng", "Hưng Phúc", "Lê Lợi", "Lê Mao", "Quán Bàu", "Quang Trung", "Trung Đô", "Trường Thi", "Vinh Tân"]})

  # Southern provinces
  create_city_with_districts_and_wards(vietnam, "Bình Dương", {"Thành phố Thủ Dầu Một" => ["Chánh Mỹ", "Chánh Nghĩa", "Định Hòa", "Hiệp An", "Hiệp Thành", "Hòa Phú", "Phú Cường", "Phú Hòa", "Phú Lợi", "Phú Mỹ", "Phú Tân", "Phú Thọ", "Tân An", "Tương Bình Hiệp"]})
  create_city_with_districts_and_wards(vietnam, "Bà Rịa-Vũng Tàu", {"Thành phố Vũng Tàu" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 7", "Phường 8", "Phường 9", "Phường 10", "Phường 11", "Phường 12", "Rạch Dừa", "Thắng Nhất", "Thắng Nhì", "Thắng Tam"], "Thành phố Bà Rịa" => ["Long Hương", "Long Tâm", "Long Toàn", "Phước Hiệp", "Phước Hưng", "Phước Nguyên", "Phước Trung", "Tân Hưng"]})
  create_city_with_districts_and_wards(vietnam, "Đồng Nai", {"Thành phố Biên Hòa" => ["An Bình", "Bình Đa", "Bửu Hòa", "Bửu Long", "Hiệp Hòa", "Hố Nai", "Hóa An", "Long Bình", "Long Bình Tân", "Phước Tân", "Quang Vinh", "Quyết Thắng", "Tam Hiệp", "Tam Hòa", "Tân Biên", "Tân Hiệp", "Tân Hòa", "Tân Mai", "Tân Phong", "Tân Tiến", "Tân Vạn", "Thống Nhất", "Trảng Dài", "Trung Dũng"]})
  create_city_with_districts_and_wards(vietnam, "Long An", {"Thành phố Tân An" => ["Khánh Hậu", "Lợi Bình Nhơn", "Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 6", "Phường 7", "Tân Khánh"]})
  create_city_with_districts_and_wards(vietnam, "Tiền Giang", {"Thành phố Mỹ Tho" => ["Phường 1", "Phường 2", "Phường 3", "Phường 4", "Phường 5", "Phường 6", "Phường 7", "Phường 8", "Phường 9", "Phường 10", "Đạo Thạnh", "Mỹ Phong", "Tân Long", "Thới Sơn", "Trung An"]})

  puts "Location seed data created successfully!"
  puts "Created or verified: 1 country, #{City.count} cities, #{District.count} districts, and #{Ward.count} wards with proper Vietnamese names."
end