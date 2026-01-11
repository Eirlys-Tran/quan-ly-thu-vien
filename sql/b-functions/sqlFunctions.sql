
--1/ Viết hàm tính số tiền phạt

    CREATE FUNCTION dbtv.fn_TinhTienPhat
    (
        @MaPhieuMuon INT,
        @MaSach INT
    )
    RETURNS DECIMAL(18,2)
    AS
    BEGIN
        DECLARE @TienPhat DECIMAL(18,2) = 0;
        DECLARE @SoNgayTre INT = 0;
        DECLARE @TrangThaiMuon NVARCHAR(50);
        DECLARE @TrangThaiSach NVARCHAR(50);
        DECLARE @DonGia DECIMAL(10,2);
        DECLARE @NgayTraDuKien DATE;
        DECLARE @NgayTraThucTe DATE;

        SELECT 
            @TrangThaiMuon = ct.TrangThaiMuon,
            @TrangThaiSach = ct.TrangThaiSach,
            @NgayTraDuKien = ct.NgayTraDuKien,
            @NgayTraThucTe = ISNULL(ct.NgayTraThucTe, CAST(GETDATE() AS DATE)),
            @DonGia = s.DonGia
        FROM ChiTietPhieuMuon ct
        INNER JOIN Sach s ON ct.MaSach = s.MaSach
        WHERE ct.MaPhieuMuon = @MaPhieuMuon
        AND ct.MaSach = @MaSach;

        -- Trễ hạn
        IF (@TrangThaiMuon = N'Trễ hạn')
        BEGIN
            SET @SoNgayTre = DATEDIFF(DAY, @NgayTraDuKien, @NgayTraThucTe);
            SET @TienPhat = @SoNgayTre * 5000;
        END

        -- Hỏng sách
        IF (@TrangThaiSach = N'Hỏng')
            SET @TienPhat = @TienPhat + (@DonGia * 0.3);

        -- Mất sách
        IF (@TrangThaiSach = N'Mất')
            SET @TienPhat = @TienPhat + @DonGia;

        RETURN @TienPhat;
    END;
    GO

    -- Select 
    SELECT
        dg.MaDocGia,
        dg.HoTen        AS TenDocGia,
        pm.MaPhieuMuon, 
        s.MaSach,
        s.TenSach,
        ct.TrangThaiMuon,
        ct.TrangThaiSach,
        dbo.fn_TinhTienPhat(pm.MaPhieuMuon, s.MaSach) AS TienPhat
    FROM ChiTietPhieuMuon ct
    INNER JOIN PhieuMuon pm   ON ct.MaPhieuMuon = pm.MaPhieuMuon
    INNER JOIN TheThuVien t  ON pm.MaThe = t.MaThe
    INNER JOIN DocGia dg     ON t.MaDocGia = dg.MaDocGia
    INNER JOIN Sach s        ON ct.MaSach = s.MaSach
    WHERE ct.TrangThaiMuon IN (N'Trễ hạn', N'Đang mượn', N'Đã trả');

-- 2/ Viết hàm kiểm tra số lượng sách còn lại

    CREATE FUNCTION dbo.fn_SoLuongSachConLai
    (
        @MaSach INT
    )
    RETURNS INT
    AS
    BEGIN
        DECLARE @SoLuongBanDau INT = 0;
        DECLARE @SoLuongDangMuon INT = 0;

        -- Lấy số lượng sách ban đầu trong kho
        SELECT @SoLuongBanDau = SoLuong
        FROM Sach
        WHERE MaSach = @MaSach;

        -- Đếm số sách đang được mượn hoặc trễ hạn
        SELECT @SoLuongDangMuon = COUNT(*)
        FROM ChiTietPhieuMuon
        WHERE MaSach = @MaSach
        AND TrangThaiMuon IN (N'Đang mượn', N'Trễ hạn');

        -- Tính số lượng sách còn lại
        RETURN ISNULL(@SoLuongBanDau, 0) - ISNULL(@SoLuongDangMuon, 0);
    END;
    GO

    -- Select 
    SELECT 
        MaSach,
        TenSach,
        SoLuong,
        dbo.fn_SoLuongSachConLai(MaSach) AS SoLuongConLai
    FROM Sach;

-- 3/ Viết hàm đếm số lượng sách mà đọc giả đã mượn

    CREATE FUNCTION dbo.fn_SoSachDocGiaMuon
    (
        @MaDocGia INT
    )
    RETURNS INT
    AS
    BEGIN
        DECLARE @Tong INT = 0;

        SELECT @Tong = COUNT(ct.MaSach)
        FROM ChiTietPhieuMuon ct
        INNER JOIN PhieuMuon pm ON ct.MaPhieuMuon = pm.MaPhieuMuon
        INNER JOIN TheThuVien t ON pm.MaThe = t.MaThe
        WHERE t.MaDocGia = @MaDocGia
        AND ct.TrangThaiMuon IN (N'Đang mượn', N'Trễ hạn');

        RETURN @Tong;
    END;
    GO

    -- Select 
    SELECT 
        MaDocGia,
        HoTen,
        dbo.fn_SoSachDocGiaMuon(MaDocGia) AS SoSachDangMuon
    FROM DocGia;