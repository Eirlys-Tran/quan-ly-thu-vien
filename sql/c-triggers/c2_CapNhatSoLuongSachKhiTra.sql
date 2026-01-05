-- 2.	2.	Cập nhật số lượng sách khi trả: Khi update TrangThaiMuon từ 'Đang mượn' hoặc 'Trễ hẹn' sang 'Đã trả' và TrangThaiSach là 'Tốt', tự động tăng lại SoLuong trong SACH

USE QuanLyThuVienDB;
GO

IF OBJECT_ID('dbo.c2_CapNhatSoLuongSachKhiTra', 'TR') IS NOT NULL
    DROP TRIGGER dbo.c2_CapNhatSoLuongSachKhiTra;
GO

CREATE TRIGGER c2_CapNhatSoLuongSachKhiTra
ON dbo.ChiTietPhieuMuon
AFTER UPDATE
AS
BEGIN
    IF Update(TrangThaiMuon)
    BEGIN
        UPDATE s
        SET s.SoLuong = s.SoLuong + 1
        FROM SACH s JOIN inserted i ON s.MaSach = i.MaSach
            JOIN deleted d ON i.MaSach = d.MaSach AND i.MaPhieuMuon = d.MaPhieuMuon
        WHERE i.TrangThaiMuon = N'Đã trả' AND d.TrangThaiMuon IN (N'Đang mượn', N'Trễ hẹn') AND i.TrangThaiSach = N'Tốt';
    END
END