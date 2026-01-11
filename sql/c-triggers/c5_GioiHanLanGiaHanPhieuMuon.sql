-- 5.	Kiểm tra gia hạn: Đảm bảo một chi tiết phiếu mượn chỉ gia hạn 1 lần cho 1 sách

USE QuanLyThuVienDB;
GO

IF OBJECT_ID('dbo.c5_KiemTraGiaHan', 'TR') IS NOT NULL
    DROP TRIGGER dbo.c5_KiemTraGiaHan;
GO

CREATE TRIGGER c5_KiemTraGiaHan
ON dbo.YeuCauGiaHan
INSTEAD OF INSERT
AS
BEGIN

    IF EXISTS (
        SELECT 1
    FROM inserted i
        JOIN dbo.YeuCauGiaHan y ON i.MaPhieuMuon = y.MaPhieuMuon AND i.MaSach = y.MaSach
    )
    BEGIN
        RAISERROR(N'Chỉ được gia hạn 1 lần cho 1 sách', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    INSERT INTO dbo.YeuCauGiaHan
        (MaPhieuMuon, MaSach, NgayTao, NgayGiaHan, TrangThai)
    SELECT MaPhieuMuon, MaSach, NgayTao, NgayGiaHan, TrangThai
    FROM inserted;

END
