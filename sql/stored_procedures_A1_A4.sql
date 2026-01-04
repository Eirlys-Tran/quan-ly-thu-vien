-- =====================================================
-- STORED PROCEDURES A1 - A4
-- QUẢN LÝ THƯ VIỆN
-- =====================================================

USE QuanLyThuVienDB;
GO

-- =====================================================
-- FUNCTIONS HỖ TRỢ
-- =====================================================

-- Function 1: Kiểm tra nợ sách quá hạn
-- Return: 1 nếu có sách quá hạn chưa trả, 0 nếu không
CREATE OR ALTER FUNCTION dbo.fn_KiemTraNoQuaHan
(
    @MaThe INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @CoNoQuaHan BIT = 0;
    
    -- Kiểm tra xem có chi tiết phiếu mượn nào quá hạn chưa trả không
    IF EXISTS (
        SELECT 1
        FROM ChiTietPhieuMuon ctpm
        INNER JOIN PhieuMuon pm ON ctpm.MaPhieuMuon = pm.MaPhieuMuon
        WHERE pm.MaThe = @MaThe
            AND ctpm.TrangThaiMuon IN (N'Đang mượn', N'Trễ hạn', N'Đã gia hạn', N'Đặt trước')
            AND ctpm.NgayTraDuKien < GETDATE()
            AND ctpm.NgayTraThucTe IS NULL
    )
    BEGIN
        SET @CoNoQuaHan = 1;
    END
    
    RETURN @CoNoQuaHan;
END;
GO

-- Function 2: Kiểm tra số lượng sách hiện có
-- Return: Số lượng sách còn lại trong kho
CREATE OR ALTER FUNCTION dbo.fn_KiemTraSoLuongSach
(
    @MaSach INT
)
RETURNS INT
AS
BEGIN
    DECLARE @SoLuongConLai INT;
    DECLARE @TongSoLuong INT;
    DECLARE @SoLuongDangMuon INT;
    
    -- Lấy tổng số lượng sách
    SELECT @TongSoLuong = SoLuong
    FROM Sach
    WHERE MaSach = @MaSach;
    
    -- Đếm số lượng sách đang được mượn (chưa trả)
    SELECT @SoLuongDangMuon = COUNT(*)
    FROM ChiTietPhieuMuon
    WHERE MaSach = @MaSach
        AND TrangThaiMuon IN (N'Đang mượn', N'Trễ hạn', N'Đã gia hạn', N'Đặt trước');
    
    SET @SoLuongConLai = @TongSoLuong - ISNULL(@SoLuongDangMuon, 0);
    
    RETURN ISNULL(@SoLuongConLai, 0);
END;
GO

-- Function 3: Tính tiền phạt trễ hạn / mất sách
-- Input: MaPhieuMuon, MaSach, TrangThaiMuon, TrangThaiSach
-- Return: Số tiền phạt
CREATE OR ALTER FUNCTION dbo.fn_TinhTienPhat
(
    @MaPhieuMuon INT,
    @MaSach INT,
    @TrangThaiMuon NVARCHAR(50),
    @TrangThaiSach NVARCHAR(50)
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @TienPhat DECIMAL(18, 2) = 0;
    DECLARE @SoNgayQuaHan INT = 0;
    DECLARE @DonGia DECIMAL(10, 2);
    DECLARE @NgayTraDuKien DATETIME2(7);
    DECLARE @NgayTraThucTe DATETIME2(7);
    DECLARE @TienPhatMotNgay DECIMAL(18, 2) = 20000; -- 20,000 VNĐ/ngày (theo business rule)
    
    -- Lấy thông tin sách và chi tiết phiếu mượn
    SELECT 
        @DonGia = s.DonGia,
        @NgayTraDuKien = ctpm.NgayTraDuKien,
        @NgayTraThucTe = ctpm.NgayTraThucTe
    FROM ChiTietPhieuMuon ctpm
    INNER JOIN Sach s ON ctpm.MaSach = s.MaSach
    WHERE ctpm.MaPhieuMuon = @MaPhieuMuon
        AND ctpm.MaSach = @MaSach;
    
    -- Tính số ngày quá hạn
    IF @NgayTraThucTe IS NOT NULL AND @NgayTraDuKien < @NgayTraThucTe
    BEGIN
        SET @SoNgayQuaHan = DATEDIFF(DAY, @NgayTraDuKien, @NgayTraThucTe);
    END
    ELSE IF @NgayTraThucTe IS NULL AND @NgayTraDuKien < GETDATE()
    BEGIN
        SET @SoNgayQuaHan = DATEDIFF(DAY, @NgayTraDuKien, GETDATE());
    END
    
    -- Tính tiền phạt dựa trên tình trạng sách (theo business rule)
    -- Thiệt hại về sách: mất sách + hư hỏng nặng tính theo giá trị mua mới
    -- Hỗ trợ cả giá trị cũ (từ dữ liệu mẫu) và giá trị mới (theo business rules)
    IF @TrangThaiSach IN (N'Mất sách', N'Mất')
    BEGIN
        -- Nếu mất sách: phạt bằng giá sách (giá trị mua mới)
        SET @TienPhat = ISNULL(@DonGia, 0);
    END
    ELSE IF @TrangThaiSach IN (N'Hư hỏng nặng', N'Hỏng')
    BEGIN
        -- Nếu hư hỏng nặng: phạt bằng giá sách (giá trị mua mới - theo business rule)
        -- Business rule: "thiệt hại về sách: mất sách + hư hỏng nặng tính theo giá trị mua mới"
        SET @TienPhat = ISNULL(@DonGia, 0);
        
        -- Nếu có quá hạn, cộng thêm tiền phạt quá hạn
        IF @SoNgayQuaHan > 0
        BEGIN
            SET @TienPhat = @TienPhat + (@SoNgayQuaHan * @TienPhatMotNgay);
        END
    END
    ELSE IF @SoNgayQuaHan > 0
    BEGIN
        -- Nếu quá hạn nhưng sách còn nguyên vẹn (Tốt hoặc Nguyên vẹn): chỉ tính tiền phạt quá hạn (20k/ngày)
        SET @TienPhat = @SoNgayQuaHan * @TienPhatMotNgay;
    END
    
    RETURN ISNULL(@TienPhat, 0);
END;
GO

-- =====================================================
-- STORED PROCEDURES
-- =====================================================

-- A1: Tạo phiếu mượn
-- Kiểm tra: độc giả có đang nợ chưa trả sách không, thẻ thư viện, sách
-- Insert: PHIEUMUON và CHITIETPHIEUMUON
CREATE OR ALTER PROCEDURE sp_TaoPhieuMuon
    @MaThe INT,
    @MaNhanVien INT,
    @DanhSachSach NVARCHAR(MAX), -- Format: 'MaSach1,MaSach2,MaSach3'
    @SoNgayMuon INT = 14, -- Mặc định mượn 14 ngày
    @MaPhieuMuon INT OUTPUT,
    @ThongBao NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Kiểm tra thẻ thư viện có tồn tại không
        IF NOT EXISTS (SELECT 1 FROM TheThuVien WHERE MaThe = @MaThe)
        BEGIN
            SET @ThongBao = N'Thẻ thư viện không tồn tại!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra thẻ thư viện có còn hiệu lực không
        DECLARE @TrangThaiThe NVARCHAR(50);
        DECLARE @NgayHetHan DATETIME2(7);
        
        SELECT @TrangThaiThe = TrangThai, @NgayHetHan = NgayHetHan
        FROM TheThuVien
        WHERE MaThe = @MaThe;
        
        -- Kiểm tra trạng thái thẻ: chỉ cho phép mượn khi thẻ "Hoạt động"
        IF @TrangThaiThe NOT IN (N'Hoạt động')
        BEGIN
            SET @ThongBao = N'Thẻ thư viện không còn hoạt động! Trạng thái: ' + @TrangThaiThe;
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra thẻ chưa hết hạn
        IF @NgayHetHan < GETDATE()
        BEGIN
            SET @ThongBao = N'Thẻ thư viện đã hết hạn!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra độc giả có đang nợ sách quá hạn không
        DECLARE @CoNoQuaHan BIT;
        SET @CoNoQuaHan = dbo.fn_KiemTraNoQuaHan(@MaThe);
        
        IF @CoNoQuaHan = 1
        BEGIN
            SET @ThongBao = N'Độc giả đang có sách mượn quá hạn chưa trả. Vui lòng trả sách trước khi mượn mới!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra thời gian mượn: tối đa 2 tháng (60 ngày)
        IF @SoNgayMuon > 60
        BEGIN
            SET @ThongBao = N'Thời gian mượn tối đa là 60 ngày (2 tháng)!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        IF @SoNgayMuon <= 0
        BEGIN
            SET @ThongBao = N'Thời gian mượn phải lớn hơn 0!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Parse danh sách sách
        DECLARE @TableSach TABLE (MaSach INT);
        DECLARE @XML XML = CAST('<root><s>' + REPLACE(@DanhSachSach, ',', '</s><s>') + '</s></root>' AS XML);
        
        INSERT INTO @TableSach (MaSach)
        SELECT T.c.value('.', 'INT')
        FROM @XML.nodes('/root/s') T(c);
        
        -- Kiểm tra số lượng sách: tối đa 10 cuốn/lần
        DECLARE @SoLuongSachMuon INT;
        SELECT @SoLuongSachMuon = COUNT(*) FROM @TableSach;
        
        IF @SoLuongSachMuon > 10
        BEGIN
            SET @ThongBao = N'Mỗi lần chỉ được mượn tối đa 10 cuốn sách!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        IF @SoLuongSachMuon = 0
        BEGIN
            SET @ThongBao = N'Danh sách sách không được để trống!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra từng sách
        DECLARE @MaSach INT;
        DECLARE @SoLuongConLai INT;
        DECLARE @TenSach NVARCHAR(150);
        DECLARE @TongSoSachMuon INT = 0;
        
        DECLARE curSach CURSOR FOR
        SELECT MaSach FROM @TableSach;
        
        OPEN curSach;
        FETCH NEXT FROM curSach INTO @MaSach;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Kiểm tra sách có tồn tại không
            IF NOT EXISTS (SELECT 1 FROM Sach WHERE MaSach = @MaSach)
            BEGIN
                SET @ThongBao = N'Sách có mã ' + CAST(@MaSach AS NVARCHAR(10)) + N' không tồn tại!';
                CLOSE curSach;
                DEALLOCATE curSach;
                ROLLBACK TRANSACTION;
                RETURN;
            END
            
            -- Kiểm tra số lượng sách còn lại
            SET @SoLuongConLai = dbo.fn_KiemTraSoLuongSach(@MaSach);
            
            IF @SoLuongConLai <= 0
            BEGIN
                SELECT @TenSach = TenSach FROM Sach WHERE MaSach = @MaSach;
                SET @ThongBao = N'Sách "' + @TenSach + N'" đã hết trong kho!';
                CLOSE curSach;
                DEALLOCATE curSach;
                ROLLBACK TRANSACTION;
                RETURN;
            END
            
            SET @TongSoSachMuon = @TongSoSachMuon + 1;
            
            FETCH NEXT FROM curSach INTO @MaSach;
        END
        
        CLOSE curSach;
        DEALLOCATE curSach;
        
        -- Tạo phiếu mượn
        INSERT INTO PhieuMuon (NgayLap, TongSoSachMuon, MaThe, MaNhanVien)
        VALUES (GETDATE(), @TongSoSachMuon, @MaThe, @MaNhanVien);
        
        SET @MaPhieuMuon = SCOPE_IDENTITY();
        
        -- Tạo chi tiết phiếu mượn cho từng sách
        DECLARE curSach2 CURSOR FOR
        SELECT MaSach FROM @TableSach;
        
        OPEN curSach2;
        FETCH NEXT FROM curSach2 INTO @MaSach;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @NgayTraDuKien DATETIME2(7) = DATEADD(DAY, @SoNgayMuon, GETDATE());
            
            -- Trạng thái mặc định: "Đang mượn" (đã kiểm tra số lượng sách có sẵn ở trên)
            INSERT INTO ChiTietPhieuMuon (MaPhieuMuon, MaSach, NgayTraDuKien, TrangThaiMuon)
            VALUES (@MaPhieuMuon, @MaSach, @NgayTraDuKien, N'Đang mượn');
            
            FETCH NEXT FROM curSach2 INTO @MaSach;
        END
        
        CLOSE curSach2;
        DEALLOCATE curSach2;
        
        SET @ThongBao = N'Tạo phiếu mượn thành công! Mã phiếu mượn: ' + CAST(@MaPhieuMuon AS NVARCHAR(10));
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @ThongBao = N'Lỗi: ' + ERROR_MESSAGE();
        SET @MaPhieuMuon = NULL;
    END CATCH
END;
GO

-- A2: Gia hạn sách
-- Update NgayDuKien sau khi YEUCAUGIAHAN được duyệt
CREATE OR ALTER PROCEDURE sp_GiaHanSach
    @MaYeuCauGiaHan INT,
    @ThongBao NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Kiểm tra yêu cầu gia hạn có tồn tại không
        IF NOT EXISTS (SELECT 1 FROM YeuCauGiaHan WHERE MaYeuCauGiaHan = @MaYeuCauGiaHan)
        BEGIN
            SET @ThongBao = N'Yêu cầu gia hạn không tồn tại!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Lấy thông tin yêu cầu gia hạn
        DECLARE @MaPhieuMuon INT;
        DECLARE @MaSach INT;
        DECLARE @TrangThai NVARCHAR(50);
        DECLARE @NgayGiaHan DATETIME2(7);
        DECLARE @NgayTao DATETIME2(7);
        
        SELECT 
            @MaPhieuMuon = MaPhieuMuon,
            @MaSach = MaSach,
            @TrangThai = TrangThai,
            @NgayGiaHan = NgayGiaHan,
            @NgayTao = NgayTao
        FROM YeuCauGiaHan
        WHERE MaYeuCauGiaHan = @MaYeuCauGiaHan;
        
        -- Kiểm tra yêu cầu đã được duyệt chưa
        IF @TrangThai != N'Đã duyệt'
        BEGIN
            SET @ThongBao = N'Yêu cầu gia hạn chưa được duyệt! Trạng thái hiện tại: ' + @TrangThai;
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra: 1 sách chỉ gia hạn 1 lần
        -- Kiểm tra xem chi tiết phiếu mượn đã có trạng thái "Đã gia hạn" chưa
        DECLARE @DaGiaHan BIT = 0;
        SELECT @DaGiaHan = 1
        FROM ChiTietPhieuMuon
        WHERE MaPhieuMuon = @MaPhieuMuon
            AND MaSach = @MaSach
            AND TrangThaiMuon = N'Đã gia hạn';
        
        IF @DaGiaHan = 1
        BEGIN
            SET @ThongBao = N'Sách này đã được gia hạn rồi! Mỗi sách chỉ được gia hạn 1 lần.';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra: Ngày yêu cầu gia hạn >= 7 ngày so với ngày trả dự kiến
        DECLARE @NgayTraDuKienHienTai DATETIME2(7);
        SELECT @NgayTraDuKienHienTai = NgayTraDuKien
        FROM ChiTietPhieuMuon
        WHERE MaPhieuMuon = @MaPhieuMuon 
            AND MaSach = @MaSach;
        
        DECLARE @SoNgayTruocHan INT;
        SET @SoNgayTruocHan = DATEDIFF(DAY, @NgayTao, @NgayTraDuKienHienTai);
        
        IF @SoNgayTruocHan < 7
        BEGIN
            SET @ThongBao = N'Yêu cầu gia hạn phải được tạo trước ít nhất 7 ngày so với ngày trả dự kiến!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra chi tiết phiếu mượn có tồn tại không
        IF NOT EXISTS (
            SELECT 1 
            FROM ChiTietPhieuMuon 
            WHERE MaPhieuMuon = @MaPhieuMuon 
                AND MaSach = @MaSach
        )
        BEGIN
            SET @ThongBao = N'Chi tiết phiếu mượn không tồn tại!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Cập nhật NgayTraDuKien và trạng thái thành "đã gia hạn"
        UPDATE ChiTietPhieuMuon
        SET 
            NgayTraDuKien = @NgayGiaHan,
            TrangThaiMuon = N'Đã gia hạn'
        WHERE MaPhieuMuon = @MaPhieuMuon
            AND MaSach = @MaSach;
        
        SET @ThongBao = N'Gia hạn sách thành công! Ngày trả dự kiến mới: ' + CONVERT(NVARCHAR(20), @NgayGiaHan, 103);
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @ThongBao = N'Lỗi: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

-- A3: Xử lý trả sách
-- Update TrangThai trong CHITIETPHIEUMUON, tính tiền phạt (nếu có) và tự động tạo HOADON
CREATE OR ALTER PROCEDURE sp_XuLyTraSach
    @MaPhieuMuon INT,
    @MaSach INT,
    @TrangThaiSach NVARCHAR(50), -- N'Nguyên vẹn' (hoặc N'Tốt'), N'Hư hỏng nặng' (hoặc N'Hỏng'), N'Mất sách' (hoặc N'Mất')
    @MaNhanVien INT,
    @MaHoaDon INT OUTPUT,
    @ThongBao NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Kiểm tra chi tiết phiếu mượn có tồn tại không
        IF NOT EXISTS (
            SELECT 1 
            FROM ChiTietPhieuMuon 
            WHERE MaPhieuMuon = @MaPhieuMuon 
                AND MaSach = @MaSach
        )
        BEGIN
            SET @ThongBao = N'Chi tiết phiếu mượn không tồn tại!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra sách đã được trả chưa (kiểm tra NgayTraThucTe để an toàn hơn)
        DECLARE @TrangThaiMuonHienTai NVARCHAR(50);
        DECLARE @NgayTraDuKien DATETIME2(7);
        DECLARE @NgayTraThucTe DATETIME2(7);
        SELECT 
            @TrangThaiMuonHienTai = TrangThaiMuon,
            @NgayTraDuKien = NgayTraDuKien,
            @NgayTraThucTe = NgayTraThucTe
        FROM ChiTietPhieuMuon
        WHERE MaPhieuMuon = @MaPhieuMuon AND MaSach = @MaSach;
        
        -- Kiểm tra sách đã được trả chưa (dựa vào NgayTraThucTe hoặc trạng thái cũ "Đã trả")
        IF @NgayTraThucTe IS NOT NULL OR @TrangThaiMuonHienTai IN (N'Đã trả', N'Hoàn thành', N'Trả trễ')
        BEGIN
            SET @ThongBao = N'Sách này đã được trả rồi!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra business rule: không trễ quá 30 ngày tính từ ngày dự kiến trả
        DECLARE @SoNgayTre INT;
        SET @SoNgayTre = DATEDIFF(DAY, @NgayTraDuKien, GETDATE());
        
        IF @SoNgayTre > 30
        BEGIN
            SET @ThongBao = N'Đã quá 30 ngày kể từ hạn trả! Vui lòng liên hệ trực tiếp để xử lý.';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Lấy thông tin phiếu mượn để lấy MaDocGia
        DECLARE @MaDocGia INT;
        SELECT @MaDocGia = tt.MaDocGia
        FROM PhieuMuon pm
        INNER JOIN TheThuVien tt ON pm.MaThe = tt.MaThe
        WHERE pm.MaPhieuMuon = @MaPhieuMuon;
        
        -- Xác định trạng thái mượn mới theo business rule
        -- Trạng thái: "hoàn thành" (trả đúng hạn và sách nguyên vẹn) hoặc "trả trễ" (trả quá hạn)
        -- Tình trạng sách: "Nguyên vẹn", "Hư hỏng nặng", "Mất sách"
        DECLARE @TrangThaiMuonMoi NVARCHAR(50);
        DECLARE @TrangThaiSachMoi NVARCHAR(50);
        
        -- Validate và chuẩn hóa tình trạng sách đầu vào
        -- Hỗ trợ cả giá trị cũ (từ dữ liệu mẫu) và giá trị mới (theo business rules)
        IF @TrangThaiSach IN (N'Tốt', N'Nguyên vẹn')
        BEGIN
            SET @TrangThaiSachMoi = N'Nguyên vẹn';
        END
        ELSE IF @TrangThaiSach IN (N'Hỏng', N'Hư hỏng nặng')
        BEGIN
            SET @TrangThaiSachMoi = N'Hư hỏng nặng';
        END
        ELSE IF @TrangThaiSach IN (N'Mất', N'Mất sách')
        BEGIN
            SET @TrangThaiSachMoi = N'Mất sách';
        END
        ELSE
        BEGIN
            SET @ThongBao = N'Tình trạng sách không hợp lệ! Chỉ chấp nhận: Nguyên vẹn (hoặc Tốt), Hư hỏng nặng (hoặc Hỏng), Mất sách (hoặc Mất)';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Xác định trạng thái: "hoàn thành" hoặc "trả trễ"
        IF @SoNgayTre <= 0
        BEGIN
            -- Trả đúng hạn hoặc sớm hơn
            SET @TrangThaiMuonMoi = N'Hoàn thành';
        END
        ELSE
        BEGIN
            -- Trả quá hạn
            SET @TrangThaiMuonMoi = N'Trả trễ';
        END
        
        -- Cập nhật chi tiết phiếu mượn
        UPDATE ChiTietPhieuMuon
        SET 
            NgayTraThucTe = GETDATE(),
            TrangThaiMuon = @TrangThaiMuonMoi,
            TrangThaiSach = @TrangThaiSachMoi
        WHERE MaPhieuMuon = @MaPhieuMuon
            AND MaSach = @MaSach;
        
        -- Tính tiền phạt
        DECLARE @TienPhat DECIMAL(18, 2);
        SET @TienPhat = dbo.fn_TinhTienPhat(@MaPhieuMuon, @MaSach, @TrangThaiMuonMoi, @TrangThaiSachMoi);
        
        -- Tạo hóa đơn nếu có tiền phạt
        IF @TienPhat > 0
        BEGIN
            DECLARE @NoiDung NVARCHAR(500);
            
            IF @TrangThaiSachMoi = N'Mất sách'
            BEGIN
                SET @NoiDung = N'Đền sách mất - Mã phiếu: ' + CAST(@MaPhieuMuon AS NVARCHAR(10)) + N', Mã sách: ' + CAST(@MaSach AS NVARCHAR(10));
            END
            ELSE IF @TrangThaiSachMoi = N'Hư hỏng nặng'
            BEGIN
                SET @NoiDung = N'Phạt sách hư hỏng nặng - Mã phiếu: ' + CAST(@MaPhieuMuon AS NVARCHAR(10)) + N', Mã sách: ' + CAST(@MaSach AS NVARCHAR(10));
            END
            ELSE
            BEGIN
                SET @NoiDung = N'Phạt trả sách trễ hạn (' + CAST(@SoNgayTre AS NVARCHAR(10)) + N' ngày) - Mã phiếu: ' + CAST(@MaPhieuMuon AS NVARCHAR(10)) + N', Mã sách: ' + CAST(@MaSach AS NVARCHAR(10));
            END
            
            INSERT INTO HoaDon (NgayLap, SoTien, NoiDung, MaDocGia, MaNhanVien)
            VALUES (GETDATE(), @TienPhat, @NoiDung, @MaDocGia, @MaNhanVien);
            
            SET @MaHoaDon = SCOPE_IDENTITY();
            SET @ThongBao = N'Trả sách thành công! Tiền phạt: ' + FORMAT(@TienPhat, 'N0') + N' VNĐ. Mã hóa đơn: ' + CAST(@MaHoaDon AS NVARCHAR(10));
        END
        ELSE
        BEGIN
            SET @MaHoaDon = NULL;
            SET @ThongBao = N'Trả sách thành công! Không có tiền phạt.';
        END
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @ThongBao = N'Lỗi: ' + ERROR_MESSAGE();
        SET @MaHoaDon = NULL;
    END CATCH
END;
GO

-- A4: Thêm sách mới
-- Insert sách vào SACH, đồng thời kiểm tra các bảng liên quan TACGIA_SACH, THELOAI, TACGIA để insert tương ứng
-- Field hinhanh chỉ lưu srcpath
CREATE OR ALTER PROCEDURE sp_ThemSachMoi
    @TenSach NVARCHAR(150),
    @HinhAnh NVARCHAR(255), -- Chỉ lưu srcpath
    @MoTa NVARCHAR(500),
    @NhaXuatBan NVARCHAR(100),
    @SoLuong INT,
    @DonGia DECIMAL(10, 2),
    @MaTheLoai INT,
    @DanhSachTacGia NVARCHAR(MAX), -- Format: 'MaTacGia1,MaTacGia2' hoặc 'TenTacGia1,TenTacGia2'
    @MaSach INT OUTPUT,
    @ThongBao NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Kiểm tra thể loại có tồn tại không
        IF NOT EXISTS (SELECT 1 FROM TheLoai WHERE MaTheLoai = @MaTheLoai)
        BEGIN
            SET @ThongBao = N'Thể loại không tồn tại!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra dữ liệu đầu vào
        IF @TenSach IS NULL OR LEN(LTRIM(RTRIM(@TenSach))) = 0
        BEGIN
            SET @ThongBao = N'Tên sách không được để trống!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Kiểm tra tên sách trùng lặp (có thể bỏ qua nếu cho phép trùng tên)
        -- IF EXISTS (SELECT 1 FROM Sach WHERE TenSach = @TenSach)
        -- BEGIN
        --     SET @ThongBao = N'Tên sách đã tồn tại! Vui lòng kiểm tra lại.';
        --     ROLLBACK TRANSACTION;
        --     RETURN;
        -- END
        
        IF @SoLuong < 0
        BEGIN
            SET @ThongBao = N'Số lượng sách phải >= 0!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        IF @DonGia < 0
        BEGIN
            SET @ThongBao = N'Đơn giá phải >= 0!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Insert sách vào bảng SACH
        INSERT INTO Sach (TenSach, HinhAnh, MoTa, NhaXuatBan, SoLuong, DonGia, MaTheLoai)
        VALUES (@TenSach, @HinhAnh, @MoTa, @NhaXuatBan, @SoLuong, @DonGia, @MaTheLoai);
        
        SET @MaSach = SCOPE_IDENTITY();
        
        -- Xử lý danh sách tác giả
        IF @DanhSachTacGia IS NOT NULL AND LEN(LTRIM(RTRIM(@DanhSachTacGia))) > 0
        BEGIN
            -- Parse danh sách tác giả
            DECLARE @TableTacGia TABLE (MaTacGia INT);
            DECLARE @XML XML = CAST('<root><s>' + REPLACE(@DanhSachTacGia, ',', '</s><s>') + '</s></root>' AS XML);
            
            DECLARE @TacGiaItem NVARCHAR(100);
            DECLARE @MaTacGia INT;
            DECLARE @TenTacGia NVARCHAR(100);
            
            DECLARE curTacGia CURSOR FOR
            SELECT T.c.value('.', 'NVARCHAR(100)')
            FROM @XML.nodes('/root/s') T(c);
            
            OPEN curTacGia;
            FETCH NEXT FROM curTacGia INTO @TacGiaItem;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @TacGiaItem = LTRIM(RTRIM(@TacGiaItem));
                
                -- Kiểm tra xem là mã tác giả (số) hay tên tác giả (chuỗi)
                IF ISNUMERIC(@TacGiaItem) = 1
                BEGIN
                    -- Là mã tác giả
                    SET @MaTacGia = CAST(@TacGiaItem AS INT);
                    
                    -- Kiểm tra tác giả có tồn tại không
                    IF NOT EXISTS (SELECT 1 FROM TacGia WHERE MaTacGia = @MaTacGia)
                    BEGIN
                        SET @ThongBao = N'Tác giả có mã ' + @TacGiaItem + N' không tồn tại!';
                        CLOSE curTacGia;
                        DEALLOCATE curTacGia;
                        ROLLBACK TRANSACTION;
                        RETURN;
                    END
                END
                ELSE
                BEGIN
                    -- Là tên tác giả, tìm hoặc tạo mới
                    SELECT @MaTacGia = MaTacGia
                    FROM TacGia
                    WHERE TenTacGia = @TacGiaItem;
                    
                    IF @MaTacGia IS NULL
                    BEGIN
                        -- Tạo tác giả mới
                        INSERT INTO TacGia (TenTacGia, MoTa)
                        VALUES (@TacGiaItem, N'Tác giả mới được thêm tự động');
                        
                        SET @MaTacGia = SCOPE_IDENTITY();
                    END
                END
                
                -- Insert vào bảng TACGIA_SACH (kiểm tra trùng lặp)
                IF NOT EXISTS (
                    SELECT 1 
                    FROM TacGia_Sach 
                    WHERE MaTacGia = @MaTacGia AND MaSach = @MaSach
                )
                BEGIN
                    INSERT INTO TacGia_Sach (MaTacGia, MaSach)
                    VALUES (@MaTacGia, @MaSach);
                END
                
                FETCH NEXT FROM curTacGia INTO @TacGiaItem;
            END
            
            CLOSE curTacGia;
            DEALLOCATE curTacGia;
        END
        
        SET @ThongBao = N'Thêm sách mới thành công! Mã sách: ' + CAST(@MaSach AS NVARCHAR(10));
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @ThongBao = N'Lỗi: ' + ERROR_MESSAGE();
        SET @MaSach = NULL;
    END CATCH
END;
GO

-- =====================================================
-- TEST PROCEDURES (Optional - có thể xóa sau khi test)
-- =====================================================

/*
-- Test A1: Tạo phiếu mượn
DECLARE @MaPhieuMuon INT, @ThongBao NVARCHAR(500);
EXEC sp_TaoPhieuMuon 
    @MaThe = 1,
    @MaNhanVien = 1,
    @DanhSachSach = '1,2',
    @SoNgayMuon = 14,
    @MaPhieuMuon = @MaPhieuMuon OUTPUT,
    @ThongBao = @ThongBao OUTPUT;
SELECT @MaPhieuMuon AS MaPhieuMuon, @ThongBao AS ThongBao;

-- Test A2: Gia hạn sách
DECLARE @ThongBao2 NVARCHAR(500);
EXEC sp_GiaHanSach 
    @MaYeuCauGiaHan = 1,
    @ThongBao = @ThongBao2 OUTPUT;
SELECT @ThongBao2 AS ThongBao;

-- Test A3: Xử lý trả sách
DECLARE @MaHoaDon INT, @ThongBao3 NVARCHAR(500);
EXEC sp_XuLyTraSach 
    @MaPhieuMuon = 1,
    @MaSach = 1,
    @TrangThaiSach = N'Nguyên vẹn',
    @MaNhanVien = 1,
    @MaHoaDon = @MaHoaDon OUTPUT,
    @ThongBao = @ThongBao3 OUTPUT;
SELECT @MaHoaDon AS MaHoaDon, @ThongBao3 AS ThongBao;

-- Test A4: Thêm sách mới
DECLARE @MaSach INT, @ThongBao4 NVARCHAR(500);
EXEC sp_ThemSachMoi 
    @TenSach = N'Sách Test Mới',
    @HinhAnh = N'img/test.jpg',
    @MoTa = N'Mô tả sách test',
    @NhaXuatBan = N'NXB Test',
    @SoLuong = 10,
    @DonGia = 100000.00,
    @MaTheLoai = 1,
    @DanhSachTacGia = '1,2',
    @MaSach = @MaSach OUTPUT,
    @ThongBao = @ThongBao4 OUTPUT;
SELECT @MaSach AS MaSach, @ThongBao4 AS ThongBao;
*/

