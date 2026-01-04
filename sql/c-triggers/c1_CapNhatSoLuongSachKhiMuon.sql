-- 1.	Cập nhật số lượng sách khi mượn: Khi insert vào CHITIETPHIEUMUON, tự động giảm SoLuong trong SACH. Khi SoLuong đã bằng 0 -> thất bại.

USE QuanLyThuVienDB;
GO

IF OBJECT_ID('dbo.c1_CapNhatSoLuongSachKhiMuon', 'TR') IS NOT NULL
    DROP TRIGGER dbo.c1_CapNhatSoLuongSachKhiMuon;
GO

CREATE TRIGGER c1_CapNhatSoLuongSachKhiMuon
ON dbo.ChiTietPhieuMuon
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @SachKhongDuSoLuong INT;

    SELECT @SachKhongDuSoLuong = COUNT(s.MaSach)
    FROM SACH s JOIN (
        SELECT MaSach, COUNT(MaSach) as SoLuongMuon
        FROM inserted
        GROUP BY MaSach
    ) i ON s.MaSach = i.MaSach
    WHERE s.SoLuong < i.SoLuongMuon;

    IF @SachKhongDuSoLuong > 0
    BEGIN
        RAISERROR(N'Số lượng sách không đủ', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    ELSE
    BEGIN
        INSERT INTO ChiTietPhieuMuon
            (MaPhieuMuon, MaSach, NgayTraDuKien, NgayTraThucTe, TrangThaiMuon, TrangThaiSach)
        SELECT MaPhieuMuon, MaSach, NgayTraDuKien, NgayTraThucTe, TrangThaiMuon, TrangThaiSach
        FROM inserted;

        UPDATE s
        SET s.SoLuong = s.SoLuong - i.SoLuongMuon
        FROM SACH s JOIN (
            SELECT MaSach, COUNT(MaSach) as SoLuongMuon
            FROM inserted
            GROUP BY MaSach
        ) i ON s.MaSach = i.MaSach;
    END
END