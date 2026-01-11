-- 3. Kiểm tra thẻ thư viện: Ngăn insert vào PHIEUMUON nếu THETHUVIEN đó đã hết hạn/bị khóa

USE QuanLyThuVienDB;
GO

IF OBJECT_ID('dbo.c3_KiemTraTheThuVien', 'TR') IS NOT NULL
    DROP TRIGGER dbo.c3_KiemTraTheThuVien;
GO

CREATE TRIGGER c3_KiemTraTheThuVien
ON dbo.PhieuMuon
INSTEAD OF INSERT
AS
BEGIN

    IF EXISTS (
        SELECT 1
    FROM inserted i JOIN TheThuVien t ON i.MaThe = t.MaThe
    WHERE t.NgayHetHan < GETDATE() OR t.TrangThai != N'Hoạt động'
    )
    BEGIN
        RAISERROR(N'Thẻ thư viện đã hết hạn hoặc bị khóa', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    INSERT INTO PhieuMuon
        (NgayLap, TongSoSachMuon, MaThe, MaNhanVien)
    SELECT NgayLap, TongSoSachMuon, MaThe, MaNhanVien
    FROM inserted;
END
GO

--