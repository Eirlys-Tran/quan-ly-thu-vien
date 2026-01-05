## A. Stored Procedures
1.	Tạo phiếu mượn: kt độc giả có đang nợ chưa trả sách không, thẻ thư viện, sách =>insert PHIEUMUON và CHITIETPHIEUMUON (gọi function kt nợ quá hạn, sl sách)
2.	Gia hạn sách: Update NgayDuKien sau khi YEUCAUGIAHAN được duyệt
3.	Xử lý trả sách: Update TrangThai trong CHITIETPHIEUMUON, tính tiền phạt (nếu có) và tự động tạo HOADON (gọi function tính tiền phạt).
4.	Thêm sách mới: Insert sách vào SACH, đồng thời kt các bảng liên quan TACGIA_SACH, THELOAI, TACGIA để insert tương ứng (field hinhanh chỉ lưu srcpath)
5.	Cập nhật tài khoản: Thay đổi mật khẩu hoặc trạng thái hoạt động của nhân viên/độc giả trong bảng TAIKHOAN (consider)
6.	Duyệt yêu cầu gia hạn: nếu duyệt thì cập nhật NgayDuKien trong CHITIETPHIEUMUON + trạng thái yêu cầu, ngược lại chỉ cập nhật tình trạng yêu cầu
7.	Hủy thẻ độc giả: Kiểm tra độc giả có mượn sách không. Không còn nợ sách TrangThai thẻ = 'Bị hủy' + vô hiệu TAIKHOAN tương ứng
## B. Functions
1.	Tính tiền phạt trễ hạn / mất sách: input MaPhieuMuon, MaSach, trangthai mượn, trangthaisach. return số tiền phạt dựa trên: số ngày quá hạn, tình trạng sách. Trường hợp phieumuon quá hạn + mất sách -> ưu tiên tạo hoadon đền sách
2.	Kiểm tra số lượng sách hiện có: return số lượng sách còn lại trong kho (Tổng SoLuong - số lượng đang được mượn) -> thống kê.
3.	Danh sách sách theo tác giả: return danh sách tất cả sách của 1 tác giả cụ thể
4.	Danh sách sách theo thể loại: return danh sách tất cả sách của 1 thể loại cụ thể
5.	Danh sách sách mượn quá hạn theo độc giả: return danh sách tất cả sách đang mượn bị quá hạn theo 1 độc giả cụ thể
6.	Lấy tên độc giả từ thẻ thư viện: return họ tên của độc giả khi biết MaThe
7.	Kiểm tra nợ sách quá hạn: return độc giả đó có cuốn sách nào quá hạn chưa trả không để ngăn việc mượn mới (có thể sử dụng bool)

## C. Triggers 
1.	Cập nhật số lượng sách khi mượn: Khi insert vào CHITIETPHIEUMUON, tự động giảm SoLuong trong SACH. Khi SoLuong đã bằng 0 -> thất bại.
2.	Cập nhật số lượng sách khi trả: Khi update TrangThaiMuon từ 'Đang mượn' hoặc 'Trễ hẹn' sang 'Đã trả' và TrangThaiSach là 'Tốt', tự động tăng lại SoLuong trong SACH
3.	Kiểm tra thẻ thư viện: Ngăn insert vào PHIEUMUON nếu THETHUVIEN đó đã hết hạn/bị khóa
4.	Tự động tạo tài khoản: Khi insert DOCGIA, tự động tạo một dòng tương ứng trong bảng TAIKHOAN với username = họ tên không dấu, pwd = cccd
5.	Kiểm tra gia hạn: Đảm bảo một chi tiết phiếu mượn chỉ gia hạn 1 lần
6.	Kiểm tra cccd và sdt: Ngăn insert/update CCCD và SDT bị trùng lặp trong bảng DOCGIA và NHANVIEN
7.	Kiểm tra sách trước khi xóa: Ngăn delete một mã sách nếu mã đó vẫn còn tồn tại trong bảng CHITIETPHIEUMUON ở trạng thái 'Đang mượn'
## D. Cursors
1.	Kiểm tra sách trễ hạn: kiểm tra các CHITIETPHIEUMUON đã quá hạn nhưng chưa trả => chuyển trạng thái thẻ thư viện = "Bị khóa"
2.	Phân loại nguồn thu: dựa vào danh sách HOADON trong tháng để phân loại nguồn thu (thu từ phạt, thu từ làm thẻ) => phục vụ thống kê
3.	Tự động reject yêu cầu gia hạn: dựa vào YEUCAUGIAHAN, nếu yêu cầu ở trạng thái 'Chờ' quá 3 ngày mà chưa được duyệt thì tự động chuyển thành 'từ chối'
## E. Reports
1.	Thống kê Top 10 sách mượn nhiều nhất: Thống kê dựa trên bảng CHITIETPHIEUMUON và SACH.
2.	Thống kê độc giả nợ sách quá hạn: Danh sách độc giả, số điện thoại và các sách đang giữ quá hạn
3.	Thống kê doanh thu theo thời gian: Tổng số tiền từ bảng HOADON theo ngày/tháng/quý/năm
4.	Thống kê tình trạng sách theo Thể loại: số lượng sách hiện có, đang mượn/hư hỏng theo từng THELOAI.
5.	Thống kê tỷ lệ sách hư hỏng: theo tháng/quý/năm
6.	Thống kê danh sách thẻ sắp hết hạn: các thẻ thư viện sẽ hết hạn trong vòng 30 ngày
