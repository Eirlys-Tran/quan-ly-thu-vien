USE QuanLyThuVienDB;
GO

-- ==============================
-- A. STORED PROCEDURE
-- ==============================

-- 1. Tạo phiếu mượn
-- Kiểm tra: Độc giả có đang mượn sách, thẻ thư viện, số lượng sách
-- Gọi func kt nợ sách quá hạn, số lượng sách
CREATE OR ALTER PROCEDURE dbo.sp_TaoPhieuMuon (@MaThe INT, @MaNhanVien INT, @TongSach INT, @DSSach NVARCHAR(MAX), @SoNgayMuon INT, @MaPhieu INT OUT, @ThongBao NVARCHAR(200) OUT)
AS
BEGIN
	BEGIN TRY
		BEGIN TRAN;
			-- Kiểm tra mã thẻ thư viện còn hoạt động không
			IF NOT EXISTS (SELECT 1 FROM TheThuVien WHERE MaThe = @MaThe)
			BEGIN
				RAISERROR(N'Thẻ thư viện không tồn tại!', 16, 1);
				RETURN;
			END

			-- Kiểm tra độc giả có đang nợ sách không
			DECLARE @CoNoQuaHan BIT = dbo.fn_KiemTraNoSach(@MaThe);
			IF @CoNoQuaHan = 1
			BEGIN
				RAISERROR(N'Độc giả đang có sách mượn quá hạn chưa trả. Vui lòng trả sách trước khi mượn mới!', 16, 1);
				RETURN;
			END

			-- Kiểm tra thời gian mượn: tối đa 2 tháng (60 ngày)
			IF @SoNgayMuon > 60 OR @SoNgayMuon <= 0
			BEGIN
				RAISERROR(N'Thời gian mượn tối đa là 60 ngày (2 tháng)!', 16, 1);
				RETURN;
			END

			-- Kiểm tra danh sách sách
			DECLARE @tblSach TABLE (MaSach INT);
			IF @DSSach IS NULL OR LTRIM(RTRIM(@DSSach)) = ''
			BEGIN
				RAISERROR(N'Không được để trống sách khi mượn', 16, 1);
				RETURN;
			END

			INSERT INTO @tblSach(MaSach)
					SELECT CAST(LTRIM(RTRIM(value)) AS INT)
					FROM STRING_SPLIT(@DSSach, ',')
					WHERE ISNUMERIC(LTRIM(RTRIM(value))) = 1;

			IF (SELECT COUNT(*) FROM STRING_SPLIT(@DSSach, ',')) <> (SELECT COUNT(*) FROM @tblSach)
			BEGIN
				RAISERROR(N'Danh sách sách có mã không hợp lệ', 16, 1);
				RETURN;
			END

			IF (SELECT COUNT(*) FROM @tblSach) <> @TongSach
			BEGIN
				RAISERROR(N'Số lượng sách không đồng nhất', 16, 1);
				RETURN;
			END
			
			-- Kiểm tra sách tồn kho
			IF EXISTS (SELECT 1
						FROM @tblSach t LEFT JOIN Sach s ON t.MaSach = s.MaSach
						WHERE s.MaSach IS NULL OR s.SoLuong <= 0 OR s.TrangThai <> N'Đang hoạt động')
			BEGIN
				RAISERROR(N'Có sách không tồn tại hoặc đã hết',16,1);
				RETURN;
			END

			-- tạo phiếu mượn
			INSERT INTO PhieuMuon (NgayLap, TongSoSachMuon, MaThe, MaNhanVien) VALUES (GETDATE(), @TongSach, @MaThe, @MaNhanVien)
			SET @MaPhieu = SCOPE_IDENTITY()
			SET @ThongBao = N'Đã tạo phiếu mượn thành công. Mã phiếu mượn: ' + CAST(@MaPhieu AS NVARCHAR(5));

			-- tạo chitietphieumuon
			INSERT INTO ChiTietPhieuMuon(MaPhieuMuon, MaSach, NgayTraDuKien, TrangThaiMuon) SELECT @MaPhieu, MaSach, DATEADD(DAY, @SoNgayMuon, GETDATE()), N'Đang mượn'
																							FROM @tblSach;
		COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO
-- test
--DECLARE @Ma INT, @TB NVARCHAR(200);
--EXEC dbo.sp_TaoPhieuMuon @MaThe =27, @MaNhanVien = 4, @TongSach = 4, @DSSach = '7,32,33,34', @SoNgayMuon = 20, @MaPhieu = @Ma, @ThongBao = @TB;


-- 2. Yêu cầu gia hạn sách
-- Update NgayTraDuKien, TrangThaiMuon trong bảng ChiTietPhieuMuon và TrangThai trong bảng YeuCauGiaHan
-- Gọi func B2 - lấy ra maphieumuon + NgayLap của sách có trạng thái là đặt trước, kiểm tra NgayLap so sánh với NgayTao trong bảng YeuCauGiaHan
CREATE OR ALTER PROCEDURE dbo.sp_XuLyYeuCauGiaHan (@MaYeuCau INT, @ThongBao NVARCHAR(200) OUT)
AS
BEGIN
	IF NOT EXISTS (SELECT 1 FROM YeuCauGiaHan WHERE MaYeuCauGiaHan = @MaYeuCau)
	BEGIN
		RAISERROR(N'Mã yêu cầu không tồn tại!', 16, 1);
		RETURN;
	END

	DECLARE @MaPhieu INT, @MaSach INT;
	SELECT @MaPhieu = MaPhieuMuon, @MaSach = MaSach
	FROM YeuCauGiaHan
	WHERE MaYeuCauGiaHan = @MaYeuCau;

	IF EXISTS (SELECT 1 FROM ChiTietPhieuMuon WHERE MaPhieuMuon = @MaPhieu AND MaSach = @MaSach AND TrangThaiMuon = N'Trễ hạn' AND NgayTraThucTe IS NULL)
	BEGIN
		UPDATE YeuCauGiaHan SET TrangThai = N'Từ chối' WHERE MaYeuCauGiaHan = @MaYeuCau;
		SET @ThongBao = N'Sách đã quá hạn trả. Gia hạn thất bại với mã phiếu mượn: ' + CAST(@MaPhieu AS NVARCHAR(10)) + ', mã sách:' + CAST(@MaSach AS NVARCHAR(10));
	END
	
	-- lấy ra danh sách yêu cầu đang chờ duyệt
	DECLARE @SachDT INT = (SELECT COUNT(*) FROM dbo.fn_LaySachDatTruoc (@MaSach));
	DECLARE @tblGiaHan TABLE (MaPhieuMuon INT, MaSach INT, NgayTaoYC DATE, NgayGiaHanMoi DATE, NgayTraDuKien DATE, NgayLapPhieu DATE)

	INSERT INTO @tblGiaHan (MaPhieuMuon, MaSach, NgayTaoYC, NgayGiaHanMoi, NgayTraDuKien)
				SELECT yc.MaPhieuMuon, yc.MaSach, yc.NgayTao, yc.NgayGiaHan, ct.NgayTraDuKien
				FROM YeuCauGiaHan yc JOIN ChiTietPhieuMuon ct ON yc.MaPhieuMuon = ct.MaPhieuMuon AND yc.MaSach = ct.MaSach
				WHERE yc.MaPhieuMuon = @MaPhieu AND yc.MaSach = @MaSach AND yc.TrangThai = N'Đang chờ';
	
	IF @SachDT > 0
	BEGIN
		UPDATE ycgh SET NgayLapPhieu = dt.NgayLap
				FROM @tblGiaHan ycgh JOIN dbo.fn_LaySachDatTruoc (@MaSach) dt ON ycgh.MaPhieuMuon = dt.MaPhieuMuon;
		
		-- Duyệt: ngày yêu cầu gia hạn < ngày tạo mượn sách VÀ <= so với ngày trả dự kiến
		IF EXISTS (SELECT 1 FROM @tblGiaHan WHERE NgayTaoYC < NgayLapPhieu AND DATEDIFF(DAY, NgayTaoYC, NgayTraDuKien) >= 7)
		BEGIN
			UPDATE ct SET ct.NgayTraDuKien = t.NgayGiaHanMoi, ct.TrangThaiMuon = N'Đã gia hạn'
						FROM ChiTietPhieuMuon ct JOIN @tblGiaHan t ON ct.MaPhieuMuon = t.MaPhieuMuon AND ct.MaSach = t.MaSach
						WHERE ct.MaPhieuMuon = @MaPhieu AND ct.MaSach = @MaSach;

			UPDATE YeuCauGiaHan SET TrangThai = N'Đã duyệt' WHERE MaYeuCauGiaHan = @MaYeuCau;
			SET @ThongBao = 'Gia hạn thành công với mã phiếu mượn: ' + CAST(@MaPhieu AS NVARCHAR(10)) + ', mã sách:' + CAST(@MaSach AS NVARCHAR(10));
		END

		-- từ chối
		IF EXISTS (SELECT 1 FROM @tblGiaHan WHERE (NgayTaoYC < NgayLapPhieu AND DATEDIFF(DAY, NgayTaoYC, NgayTraDuKien) < 7) OR NgayTaoYC > NgayLapPhieu)
		BEGIN
			UPDATE YeuCauGiaHan SET TrangThai = N'Từ chối' WHERE MaYeuCauGiaHan = @MaYeuCau;
			SET @ThongBao = N'Sách nằm trong danh sách mượn trước. Gia hạn thất bại với mã phiếu mượn: ' + CAST(@MaPhieu AS NVARCHAR(10)) + ', mã sách:' + CAST(@MaSach AS NVARCHAR(10));
		END
	END
	ELSE
	BEGIN
		UPDATE ct SET ct.NgayTraDuKien = t.NgayGiaHanMoi, ct.TrangThaiMuon = N'Đã gia hạn'
					FROM ChiTietPhieuMuon ct JOIN @tblGiaHan t ON ct.MaPhieuMuon = t.MaPhieuMuon AND ct.MaSach = t.MaSach
					WHERE ct.MaPhieuMuon = @MaPhieu AND ct.MaSach = @MaSach;

		UPDATE YeuCauGiaHan SET TrangThai = N'Đã duyệt' WHERE MaYeuCauGiaHan = @MaYeuCau;
		SET @ThongBao = 'Gia hạn thành công với mã phiếu mượn: ' + CAST(@MaPhieu AS NVARCHAR(10)) + ', mã sách:' + CAST(@MaSach AS NVARCHAR(10));
	END
END;
GO
-- test 


-- 3. Xử lý trả sách
-- Update TrangThai trong bảng ChiTietPhieuMuon
-- Tính tiền phạt và tự động tạo hóa đơn phạt (nếu có - gọi func Tính tiền phạt trễ hạn/mất sách)
CREATE OR ALTER PROCEDURE dbo.sp_XuLyTraSach (@MaPhieuMuon INT, @DSSach NVARCHAR(MAX), @DSTrangThaiSach NVARCHAR(MAX), @MaNhanVien INT, @ThongBao NVARCHAR(200) OUT)
AS
BEGIN
	BEGIN TRY
		BEGIN TRAN;
			-- Kiểm tra mã phiếu mượn hợp lệ + lấy ra mã thẻ
			DECLARE @MaThe INT = (SELECT MaThe FROM PhieuMuon WHERE MaPhieuMuon = @MaPhieuMuon)
			IF @MaThe IS NULL
			BEGIN
				RAISERROR(N'Phiếu mượn không tồn tại', 16, 1);
				RETURN;
			END

			-- Kiểm tra MaNhanVien hợp lệ không
			IF NOT EXISTS (SELECT 1 FROM NhanVien WHERE MaNhanVien = @MaNhanVien AND TrangThai = N'Hoạt động')
			BEGIN
				RAISERROR(N'Nhân viên không tồn tại', 16, 1);
				RETURN;
			END

			-- Kiểm tra danh sách và số lượng trong bảng tạm lấy từ input
			DECLARE @tblInput TABLE (ID INT PRIMARY KEY, MaSachRaw NVARCHAR(50), TrangThaiRaw NVARCHAR(50));
			INSERT INTO @tblInput (ID, MaSachRaw) SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), LTRIM(RTRIM(value))
													FROM STRING_SPLIT(@DSSach, ',');

			DECLARE @CountSach INT = @@ROWCOUNT;
			DECLARE @CountTrangThai INT = (SELECT COUNT(*) FROM STRING_SPLIT(@DSTrangThaiSach, ','));
			IF @CountSach <> @CountTrangThai
			BEGIN
				RAISERROR(N'Số lượng mã sách và trạng thái sách không khớp', 16, 1);
				RETURN;
			END

			UPDATE i SET TrangThaiRaw = t.value
						FROM @tblInput i JOIN (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn, LTRIM(RTRIM(value)) AS value
												FROM STRING_SPLIT(@DSTrangThaiSach, ',')) t ON i.ID = t.rn;

			IF EXISTS (SELECT 1 FROM @tblInput WHERE ISNUMERIC(MaSachRaw) = 0)
			BEGIN
				DECLARE @ErrID1 INT = (SELECT TOP 1 ID FROM @tblInput WHERE ISNUMERIC(MaSachRaw) = 0);
				RAISERROR(N'Mã sách không hợp lệ tại vị trí %d', 16, 1, @ErrID1);
				RETURN;
			END
			IF EXISTS (SELECT 1 FROM @tblInput WHERE TrangThaiRaw NOT IN (N'Tốt', N'Hỏng', N'Mất'))
			BEGIN
				DECLARE @ErrID2 INT = (SELECT TOP 1 ID FROM @tblInput WHERE TrangThaiRaw NOT IN (N'Tốt', N'Hỏng', N'Mất'));
				RAISERROR(N'Trạng thái sách không hợp lệ tại vị trí %d', 16, 1, @ErrID2);
				RETURN;
			END

			-- Bảng tạm 2 với dữ liệu đã hợp lệ
			DECLARE @tblSach TABLE (ID INT PRIMARY KEY, MaSach INT, TrangThaiSach NVARCHAR(10));
			INSERT INTO @tblSach (ID, MaSach, TrangThaiSach) SELECT ID, CAST(MaSachRaw AS INT), TrangThaiRaw
																FROM @tblInput;
			IF EXISTS (SELECT MaSach
						FROM @tblSach
						GROUP BY MaSach
						HAVING COUNT(*) > 1)
			BEGIN
				RAISERROR(N'Danh sách có mã sách bị trùng', 16, 1);
				RETURN;
			END

			-- Kiểm tra mã sách có trong ChiTietPhieuMuon không
			IF EXISTS (SELECT 1
						FROM @tblSach t LEFT JOIN ChiTietPhieuMuon ct ON ct.MaPhieuMuon = @MaPhieuMuon AND ct.MaSach = t.MaSach
						WHERE ct.MaSach IS NULL)
			BEGIN
				RAISERROR(N'Có mã sách không thuộc phiếu mượn', 16, 1);
				RETURN;
			END

			-- Update ChiTietPhieuMuon
			UPDATE ct SET NgayTraThucTe = GETDATE(), TrangThaiMuon = CASE WHEN ct.NgayTraDuKien > GETDATE() THEN N'Đã trả'
																			WHEN ct.NgayTraDuKien < GETDATE() THEN N'Trễ hạn'END,
													TrangThaiSach = s.TrangThaiSach
						FROM ChiTietPhieuMuon ct JOIN @tblSach s ON ct.MaSach = s.MaSach
						WHERE ct.MaPhieuMuon = @MaPhieuMuon AND ct.TrangThaiMuon IN (N'Đang mượn', N'Trễ hạn', N'Đã gia hạn');

			-- Tính tiền phạt và in hóa đơn
			DECLARE @InsertedID TABLE (ID INT);
			INSERT INTO HoaDon(NgayLap, SoTien, NoiDung, MaDocGia, MaNhanVien)
					OUTPUT inserted.MaHoaDon INTO @InsertedID
					SELECT GETDATE(), dbo.fn_TinhTienPhat(ct.MaPhieuMuon, ct.MaSach) AS SoTien,
							CASE WHEN ct.TrangThaiMuon IN (N'Đã trả', N'Trễ hạn') AND ct.TrangThaiSach IN (N'Hỏng', N'Mất') THEN N'Đền sách hỏng/mất'
								WHEN ct.TrangThaiMuon = N'Trễ hạn' AND ct.TrangThaiSach = N'Tốt' THEN N'Trả tiền trễ hạn'
							END AS NoiDung, tv.MaDocGia, @MaNhanVien 
					FROM TheThuVien tv JOIN PhieuMuon pm ON tv.MaThe = pm.MaThe
										JOIN ChiTietPhieuMuon ct ON pm.MaPhieuMuon = ct.MaPhieuMuon
										JOIN @tblSach s ON ct.MaSach = s.MaSach
					WHERE dbo.fn_TinhTienPhat(ct.MaPhieuMuon, ct.MaSach) > 0;
			
			-- Kiểm tra sau khi độc giả trả sách rồi thì còn sách nào trễ hạn chưa trả không => có thực hiện khóa thẻ
			DECLARE @TreHan BIT = 0;
			IF EXISTS (SELECT 1
						FROM ChiTietPhieuMuon ct JOIN PhieuMuon pm ON ct.MaPhieuMuon = pm.MaPhieuMuon
						WHERE pm.MaThe = @MaThe AND ct.NgayTraDuKien < GETDATE() AND ct.NgayTraThucTe IS NULL)
				SET @TreHan = 1;

			IF @TreHan > 0
				EXEC dbo.sp_XuLyTrangThaiTheThuVien @MaThe, N'Khóa', @ThongBao;
			ELSE
				UPDATE TheThuVien SET TrangThai = N'Hoạt động', Updated_at = GETDATE() WHERE MaThe = @MaThe;

			-- hiển thị các mã hóa đơn nếu độc giả bị phạt tiền
			DECLARE @RowCount INT = (SELECT COUNT(*) FROM @InsertedID);
			IF @RowCount > 0
			BEGIN
				DECLARE @DanhSachID NVARCHAR(MAX) = (SELECT STRING_AGG(CAST(ID AS NVARCHAR(10)), ',') FROM @InsertedID);
				SET @ThongBao = N'Xử lý trả sách thành công và độc giả có ' + CAST(@RowCount AS NVARCHAR(10)) + ' hóa đơn với mã: ' + @DanhSachID;
			END
			ELSE
				SET @ThongBao = N'Xử lý trả sách thành công';
        COMMIT TRAN;
		
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- 4. Thêm sách mới
-- Insert sách vào bảng Sach
-- Kiểm tra trước khi insert:
-- Kiểm tra sách trùng tên, tác giả và thể loại đã có, TacGia_Sach đã có dữ liệu chưa.
-- Khi insert sách thành công thì insert cho bảng TacGia_Sach (attr HinhAnh sẽ lưu srcpath)
CREATE OR ALTER PROCEDURE dbo.sp_ThemSachMoi
(@TenSach NVARCHAR(150), @HinhAnh NVARCHAR(255), @MoTa NVARCHAR(500), @NhaXuatBan NVARCHAR(100), @SoLuong INT, 
@DonGia DECIMAL(10,2), @MaTheLoai INT, @TacGia NVARCHAR(100), @ThongBao NVARCHAR(200) OUT)
AS
BEGIN
	BEGIN TRY
        BEGIN TRAN;
			-- Kiểm tra mã thể loại
			IF NOT EXISTS (SELECT 1 FROM TheLoai WHERE MaTheLoai = @MaTheLoai)
			BEGIN
				RAISERROR (N'Thể loại không hợp lệ', 16, 1);
				RETURN;
			END
			
			-- Kiểm tra sách trùng tên + thể loại
			IF EXISTS (SELECT 1
						FROM Sach s
						WHERE s.TenSach = @TenSach AND s.MaTheLoai = @MaTheLoai)
			BEGIN
				RAISERROR (N'Sách này đã tồn tại với thể loại tương ứng', 16, 1);
				RETURN;
			END

			-- kiểm tra đơn giá và số lượng
			IF @DonGia < 0 OR @SoLuong < 0
				RAISERROR(N'Đơn giá hoặc số lượng không hợp lệ', 16, 1);

			-- insert bảng Sach
			DECLARE @MaSachMoi INT;
			INSERT INTO Sach(TenSach, HinhAnh, MoTa, NhaXuatBan, SoLuong, DonGia, MaTheLoai, TrangThai) 
					VALUES (@TenSach, @HinhAnh, @MoTa, @NhaXuatBan, @SoLuong, @DonGia, @MaTheLoai, N'Đang hoạt động');
			SET @MaSachMoi = SCOPE_IDENTITY();

			-- tách từng row cho danh sách tác giả vào bảng tạm
			DECLARE @tblTacGiaRaw TABLE (ID INT IDENTITY(1,1), TacGiaRaw NVARCHAR(100));
			INSERT INTO @tblTacGiaRaw(TacGiaRaw) SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@TacGia, ',');

			IF EXISTS (SELECT 1 FROM @tblTacGiaRaw WHERE TacGiaRaw = '')
			BEGIN
				RAISERROR(N'Danh sách tác giả không hợp lệ', 16, 1);
				RETURN;
			END

			IF EXISTS (SELECT TacGiaRaw FROM @tblTacGiaRaw GROUP BY TacGiaRaw HAVING COUNT(*) > 1)
			BEGIN
				RAISERROR(N'Danh sách tác giả bị trùng', 16, 1);
				RETURN;
			END

			-- sau khi validate thì thêm vào bảng tạm 2
			DECLARE @tblTacGia TABLE (MaTacGia INT);
			INSERT INTO @tblTacGia(MaTacGia)
					SELECT CASE WHEN TRY_CAST(TacGiaRaw AS INT) IS NOT NULL THEN CAST(TacGiaRaw AS INT) ELSE tg.MaTacGia END
					FROM @tblTacGiaRaw r LEFT JOIN TacGia tg ON tg.TenTacGia = r.TacGiaRaw
					WHERE (TRY_CAST(TacGiaRaw AS INT) IS NOT NULL AND EXISTS (SELECT 1 FROM TacGia WHERE MaTacGia = CAST(TacGiaRaw AS INT)))
							OR (TRY_CAST(TacGiaRaw AS INT) IS NULL AND tg.MaTacGia IS NOT NULL);

			IF (SELECT COUNT(*) FROM @tblTacGia) <> (SELECT COUNT(*) FROM @tblTacGiaRaw)
				RAISERROR(N'Có tác giả không tồn tại', 16, 1);

			INSERT INTO TacGia_Sach(MaSach, MaTacGia)
					SELECT @MaSachMoi, MaTacGia
					FROM @tblTacGia;

			SET @ThongBao = N'Đã thêm sách thành công với mã sách mới là: ' + CAST(@MaSachMoi AS NVARCHAR(10));
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
			ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- 5. Hủy/Khóa thẻ thư viện của độc giả (input: mathe, loaixuly)
-- Kiểm tra độc giả còn đang mượn/nợ sách không
-- Nếu không và loaixuly = 'hủy' thì Update TrangThaiThe = 'Hủy thẻ'
-- Nếu có và loaixuly = 'khóa' thì Update TrangThaiThe = 'Khóa thẻ' và cập nhật trạng thái mượn = 'Trễ hạn' (gọi cursor D1, D2)
CREATE OR ALTER PROCEDURE dbo.sp_XuLyTrangThaiTheThuVien (@MaThe INT, @LoaiXuLy NVARCHAR(20), @ThongBao NVARCHAR(200) OUT)
AS
BEGIN
	-- kiểm tra thẻ thư viện tồn tại chưa
	IF NOT EXISTS (SELECT 1 FROM TheThuVien WHERE MaThe = @MaThe)
	BEGIN
		RAISERROR (N'Thẻ thư viện không hợp lệ', 16, 1);
		RETURN;
	END

	-- Trường hợp 1: Cập nhật trễ hạn cho phiếu mượn quá hạn và khóa thẻ
	IF @LoaiXuLy = N'Khóa'
	BEGIN
		-- kiểm tra thẻ có trong phiếu mượn không
		IF NOT EXISTS (SELECT 1 FROM PhieuMuon WHERE MaThe = @MaThe)
		BEGIN
			RAISERROR (N'Thẻ thư viện không có trong phiếu mượn', 16, 1);
			RETURN;
		END

		-- D1 - cursor 1: Cập nhật trạng thái mượn = 'Trễ hạn'
		DECLARE cur_CapNhatTreHan CURSOR FOR
		SELECT ct.MaPhieuMuon, ct.MaSach
		FROM PhieuMuon pm JOIN ChiTietPhieuMuon ct ON pm.MaPhieuMuon = ct.MaPhieuMuon
		Where pm.MaThe = @MaThe AND ct.NgayTraThucTe IS NULL AND ct.NgayTraDuKien < GETDATE() AND ct.TrangThaiMuon <> N'Trễ hạn';

		DECLARE @MaPhieu INT, @MaSach INT;
		OPEN cur_CapNhatTreHan;
		
		FETCH NEXT FROM cur_CapNhatTreHan INTO @MaPhieu, @MaSach;
		WHILE @@FETCH_STATUS = 0
		BEGIN
			UPDATE ChiTietPhieuMuon SET TrangThaiMuon = N'Trễ hạn' WHERE MaPhieuMuon = @MaPhieu AND MaSach = @MaSach;
			FETCH NEXT FROM cur_CapNhatTreHan INTO @MaPhieu, @MaSach;
		END

		CLOSE cur_CapNhatTreHan;
		DEALLOCATE cur_CapNhatTreHan;

		-- D2 - cursor 2: Cập nhật trạng thái thẻ = 'Khóa thẻ'
		DECLARE cur_KhoaThe CURSOR FOR
		SELECT DISTINCT pm.MaThe
		FROM PhieuMuon pm JOIN ChiTietPhieuMuon ct ON pm.MaPhieuMuon = ct.MaPhieuMuon
		WHERE pm.MaThe = @MaThe AND ct.NgayTraThucTe IS NULL AND ct.NgayTraDuKien < GETDATE();

		DECLARE @TheViPham INT;
		OPEN cur_KhoaThe;

		FETCH NEXT FROM cur_KhoaThe INTO @TheViPham;
		WHILE @@FETCH_STATUS = 0
		BEGIN
			UPDATE TheThuVien SET TrangThai = N'Khóa thẻ', Updated_at = GETDATE() WHERE MaThe = @TheViPham;
			FETCH NEXT FROM cur_KhoaThe INTO @TheViPham;
		END

		CLOSE cur_KhoaThe;
		DEALLOCATE cur_KhoaThe;
		SET @ThongBao = N'Đã thay đổi trạng thái mượn và khóa thẻ khi quá hạn trả sách';
	END

	-- Trường hợp 2: Cập nhật trạng thái thẻ = 'Hủy thẻ' nếu độc giả không có bất kỳ sách đang mượn/nợ/đặt trước
	IF @LoaiXuLy = N'Hủy'
	BEGIN
		IF EXISTS (SELECT 1
					FROM PhieuMuon pm JOIN ChiTietPhieuMuon ct ON pm.MaPhieuMuon = ct.MaPhieuMuon
					WHERE pm.MaThe = @MaThe AND ct.NgayTraThucTe IS NULL)
		BEGIN
			RAISERROR (N'Không thể hủy thẻ khi còn sách chưa trả', 16, 1);
			RETURN;
		END
		UPDATE TheThuVien SET TrangThai = N'Hủy thẻ', Deleted_at = GETDATE() WHERE MaThe = @MaThe;
		SET @ThongBao = N'Đã hủy thẻ thành công';
	END
END;
GO


-- ==============================
-- B. FUNCTION
-- ==============================

-- 1. Tính tiền phạt trễ hạn/mất sách:
-- Input: MaPhieuMuon, MaSach
-- Ouput: số tiền phạt
CREATE OR ALTER FUNCTION dbo.fn_TinhTienPhat (@MaPhieu INT, @MaSach INT)
RETURNS DECIMAL(18,2) AS
BEGIN
	DECLARE @TienPhat DECIMAL(18,2) = 0;
	DECLARE @SoNgayTre INT = 0;
    DECLARE @TrangThaiMuon NVARCHAR(50);
    DECLARE @TrangThaiSach NVARCHAR(50);
    DECLARE @DonGia DECIMAL(10,2);
    DECLARE @NgayTraDuKien DATE;
    DECLARE @NgayTraThucTe DATE;

	-- Lấy ra trạng thái và ngày trả
	SELECT @TrangThaiMuon = ct.TrangThaiMuon,
           @TrangThaiSach = ct.TrangThaiSach,
           @NgayTraDuKien = ct.NgayTraDuKien,
           @NgayTraThucTe = ct.NgayTraThucTe,
           @DonGia = s.DonGia
    FROM ChiTietPhieuMuon ct
    INNER JOIN Sach s ON ct.MaSach = s.MaSach
    WHERE ct.MaPhieuMuon = @MaPhieu
    AND ct.MaSach = @MaSach;

	-- Làm mất hoặc hỏng sách đền = đơn giá
	IF @TrangThaiSach = N'Hỏng' OR @TrangThaiSach = N'Mất'
		SET @TienPhat = @DonGia;

	-- Trả sách trễ hạn
	IF (@TrangThaiMuon = N'Trễ hạn' AND @NgayTraDuKien < GETDATE() AND @TrangThaiSach = N'Tốt')
	BEGIN
		SET @SoNgayTre = DATEDIFF(DAY, @NgayTraDuKien, GETDATE());
        SET @TienPhat = @SoNgayTre * 20000;
	END
	RETURN @TienPhat;
END;
GO

-- 2. Sách trong hàng chờ đặt trước
-- Input: MaSach
-- Output: NgayLap
CREATE OR ALTER FUNCTION dbo.fn_LaySachDatTruoc (@MaSach INT)
RETURNS TABLE AS
RETURN
	SELECT ct.MaPhieuMuon, pm.NgayLap
	FROM ChiTietPhieuMuon ct JOIN PhieuMuon pm ON ct.MaPhieuMuon = pm.MaPhieuMuon
	WHERE ct.MaSach = @MaSach AND ct.TrangThaiMuon = N'Đặt trước'
GO
-- select * from fn_LaySachDatTruoc (4)

-- 3. Kiểm tra nợ sách quá hạn
-- Input: MaThe
-- Output: BIT 0 hoặc 1
CREATE OR ALTER FUNCTION dbo.fn_KiemTraNoSach (@MaThe INT)
RETURNS BIT AS
BEGIN
	DECLARE @Result BIT = 0;
	IF EXISTS (SELECT 1 
				FROM ChiTietPhieuMuon ct JOIN PhieuMuon pm ON ct.MaPhieuMuon = pm.MaPhieuMuon
				WHERE pm.MaThe = @MaThe AND ct.NgayTraThucTe IS NULL AND ct.NgayTraDuKien < GETDATE() AND ct.TrangThaiMuon = N'Trễ hạn')
	BEGIN
		SET @Result = 1;
	END
	RETURN @Result;
END;
GO


-- ==============================
-- C.TRIGGER
-- ==============================

-- 1. Cập nhật số lượng sách khi mượn
-- Khi Insert/Update bảng ChiTietPhieuMuon thì giảm/tăng SoLuong bảng Sach.
-- Khi giảm mà SoLuong hiện tại đang = 0 thì thông báo 'Thất bại'
-- Tăng khi TrangThaiSach = 'Tốt'
CREATE OR ALTER TRIGGER dbo.tg_CapNhatSoLuongSach
ON dbo.ChiTietPhieuMuon
AFTER INSERT, UPDATE
AS
BEGIN
	-- Trường hợp 1: Giảm khi mượn sách
	IF EXISTS (SELECT 1
				FROM inserted i LEFT JOIN deleted d ON i.MaPhieuMuon = d.MaPhieuMuon AND i.MaSach = d.MaSach
								JOIN Sach s ON s.MaSach = i.MaSach
				WHERE d.MaPhieuMuon IS NULL AND s.SoLuong <= 0)
	BEGIN
		RAISERROR (N'Sách đã hết, không thể mượn. Hãy chuyển qua mượn trước!', 16, 1);
		ROLLBACK TRANSACTION;
		RETURN;
	END

	-- Giảm số lượng
	UPDATE s SET SoLuong = SoLuong - 1
				FROM Sach s JOIN inserted i ON s.MaSach = i.MaSach
							LEFT JOIn deleted d ON i.MaPhieuMuon = d.MaPhieuMuon AND i.MaSach = d.MaSach
				WHERE d.MaPhieuMuon IS NULL;

	-- Trường hợp 2: Tăng khi trả sách với trạng thái tốt
	IF EXISTS (SELECT 1
				FROM inserted i JOIN deleted d ON i.MaPhieuMuon = d.MaPhieuMuon AND i.MaSach = d.MaSach
				WHERE d.NgayTraThucTe IS NULL AND i.NgayTraThucTe IS NOT NULL AND i.TrangThaiSach = N'Tốt')
	BEGIN
		UPDATE s SET SoLuong = SoLuong + 1
					FROM Sach s JOIN inserted i ON s.MaSach = i.MaSach
								JOIN deleted d ON i.MaPhieuMuon = d.MaPhieuMuon AND i.MaSach = d.MaSach
					WHERE d.NgayTraThucTe IS NULL AND i.NgayTraThucTe IS NOT NULL AND i.TrangThaiSach = N'Tốt';
	END
END;
GO

-- 2. Kiểm tra thẻ thư viện
-- Thẻ hết hạn/bị khóa/vô hiệu thì không cho insert vào bảng PhieuMuon
CREATE OR ALTER TRIGGER dbo.tg_KiemTraTheThuVien
ON dbo.PhieuMuon
AFTER INSERT
AS
BEGIN
	IF EXISTS (SELECT 1
				FROM inserted i JOIN TheThuVien tv ON i.MaThe = tv.MaThe
				WHERE tv.TrangThai <> N'Hoạt động')
	BEGIN
		RAISERROR (N'Thẻ thư viện không hoạt động, Không thể tạo phiếu mượn', 16, 1);
		ROLLBACK TRANSACTION;
		RETURN;
	END
END;
GO

-- 3. Kiểm tra CCCD và SDT không trùng
-- Khi Insert/Update thì check unique cho CCCD và SDT trong bảng DocGia, NhanVien
-- DocGia
CREATE OR ALTER TRIGGER dbo.tg_KiemTraUnique_DocGia
ON dbo.DocGia
AFTER INSERT, UPDATE
AS
BEGIN
	IF EXISTS (SELECT 1
			FROM inserted i JOIN DocGia dg ON (dg.CCCD = i.CCCD OR dg.SoDienThoai = i.SoDienThoai) AND dg.MaDocGia <> i.MaDocGia)
    BEGIN
        RAISERROR (N'CCCD hoặc số điện thoại của độc giả đã tồn tại.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- NhanVien
CREATE OR ALTER TRIGGER dbo.tg_KiemTraUnique_NhanVien
ON dbo.NhanVien
AFTER INSERT, UPDATE
AS
BEGIN
	IF EXISTS (SELECT 1
			FROM inserted i JOIN NhanVien nv ON (nv.CCCD = i.CCCD OR nv.SoDienThoai = i.SoDienThoai) AND nv.MaNhanVien <> i.MaNhanVien)
    BEGIN
        RAISERROR (N'CCCD hoặc số điện thoại của nhân viên đã tồn tại.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- 4. Kiểm tra gia hạn
-- Kiểm tra phiếu mượn đó đã từng được gia hạn chưa
-- 1 MaSach chỉ gia hạn 1 lần
CREATE OR ALTER TRIGGER dbo.tg_KiemTraGiaHan
ON dbo.YeuCauGiaHan
AFTER INSERT
AS
BEGIN
    IF EXISTS (SELECT 1
				FROM inserted i JOIN dbo.YeuCauGiaHan y ON i.MaPhieuMuon = y.MaPhieuMuon AND i.MaSach = y.MaSach)
    BEGIN
        RAISERROR(N'Chỉ được gia hạn 1 lần cho 1 sách', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- 5. Giới hạn tổng số sách cho mượn
-- Khi tổng số lượng đang mượn > 10 thì ngăn không cho mượn tiếp
CREATE OR ALTER TRIGGER tg_GioiHanTongSoSachMuon
ON dbo.PhieuMuon
AFTER INSERT
AS
BEGIN
	IF EXISTS (SELECT 1
				FROM PhieuMuon pm
					JOIN inserted i ON pm.MaPhieuMuon = i.MaPhieuMuon
				GROUP BY pm.MaThe
				HAVING (
						-- Số sách đang mượn trước đó
						SELECT COUNT(*)
						FROM ChiTietPhieuMuon ct
						JOIN PhieuMuon pm2 ON ct.MaPhieuMuon = pm2.MaPhieuMuon
						WHERE pm2.MaThe = pm.MaThe
						  AND ct.TrangThaiMuon = N'Đang mượn') > 9)
	BEGIN
		RAISERROR(N'Số lượng sách mượn vượt quá giới hạn 10 cuốn cho một độc giả', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
	END
END;
GO


-- ==============================
-- D. CURSOR
-- ==============================

-- 1. Thay đổi trạng thái mượn trong ChiTietPhieuMuon
-- Kiểm tra các sách đang mượn có đang trễ hạn không. Có thì đổi TrangThaiMuon = 'Trễ hạn'
-- nằm trong A5

-- 2. Thay đổi trạng thái thẻ thư viện
-- Kiềm tra MaPhieuMuon trong bảng ChiTietPhieuMuon
-- Những mã phiếu có NgayTraDuKien < GETDATE() và NgayTraThucTe IS NULL thì đổi TrangThai của thẻ thư viện = 'Bị khóa'
-- nằm trong A5


-- ==============================
-- E. REPORT
-- ==============================

-- 1. Thống kê Top 10 sách mượn nhiều nhất theo tháng/quý/năm
--CREATE OR ALTER VIEW VW_TopSachMuonNhieuNhat AS
--SELECT TOP 10 s.TenSach, YEAR(pm.NgayLap) AS Nam, DATEPART(QUARTER, pm.NgayLap) AS Quy, MONTH(pm.NgayLap) As Thang, COUNT(ct.MaSach) AS SoLanMuon
--FROM Sach s JOIN ChiTietPhieuMuon ct ON ct.MaSach = s.MaSach
--			JOIN PhieuMuon pm ON ct.MaPhieuMuon = pm.MaPhieuMuon
--GROUP BY s.TenSach, YEAR(pm.NgayLap), DATEPART(QUARTER, pm.NgayLap), MONTH(pm.NgayLap);

---- 2. Thống kê độc giả nợ sách quá hạn
--CREATE OR ALTER VIEW VW_DocGiaNoSach AS
--SELECT dg.HoTen, s.TenSach, DATEDIFF(DAY, ct.NgayTraDuKien, GETDATE()) AS SoNgayTre
--FROM DocGia dg JOIN TheThuVien tv ON dg.MaDocGia = tv.MaDocGia
--				JOIN PhieuMuon pm ON tv.MaThe = pm.MaThe
--				JOIN ChiTietPhieuMuon ct ON pm.MaPhieuMuon = ct.MaPhieuMuon
--				JOIN Sach s ON s.MaSach = ct.MaSach
--WHERE NgayTraThucTe IS NULL AND TrangThaiMuon = N'Trễ hạn';

---- 3. Thống kê tình trạng sách theo Thể loại
--CREATE OR ALTER VW_SachTheoTheLoai AS
--SELECT tl.TenTheLoai, COUNT(*) AS SoLuongSach
--FROM Sach s JOIN TheLoai tl ON s.MaTheLoai = tl.MaTheLoai
--WHERE s.Deleted_at IS NULL
--GROUP BY tl.TenTheLoai;

---- 4. Thống kê danh sách thẻ sắp hết hạn
--CREATE OR ALTER VIEW VW_DanhSachTheSapHetHan AS
--SELECT tv.MaThe, CONVERT(DATE, tv.NgayHetHan) AS NgayHetHan, DATEDIFF(DAY, GETDATE(), tv.NgayHetHan) AS SoNgayConLai
--FROM TheThuVien tv
--WHERE tv.NgayHetHan BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE()) AND tv.TrangThai = N'Hoạt động';

---- 5. Thống kê doanh thu theo thời gian (ngày/tháng/quý/năm)
--CREATE OR ALTER VIEW VW_DoanhThu AS
--SELECT YEAR(NgayLap) AS Nam, DATEPART(QUARTER, NgayLap) AS Quy, MONTH(NgayLap) AS Thang, CAST(NgayLap AS DATE) AS Ngay, SUM(SoTien) AS DoanhThu
--FROM HoaDon
--GROUP BY YEAR(NgayLap), DATEPART(QUARTER, NgayLap), MONTH(NgayLap), CAST(NgayLap AS DATE);

---- 6. Thống kê tỷ lệ sách hỏng/mất
--CREATE OR ALTER VIEW VW_SachHongMat AS
--SELECT s.TenSach, COUNT(CASE WHEN ct.TrangThaiSach = N'Hỏng' THEN 1 END) * 1.0 / COUNT(*) AS TyLeHongSach,
--					COUNT(CASE WHEN ct.TrangThaiSach = N'Mất' THEN 1 END) * 1.0 / COUNT(*) AS TyLeMatSach
--FROM Sach s JOIN ChiTietPhieuMuon ct ON s.MaSach = ct.MaSach
--GROUP BY s.TenSach;