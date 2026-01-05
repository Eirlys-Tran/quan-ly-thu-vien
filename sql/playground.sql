USE QuanLyThuVienDB;
GO

SELECT *
FROM PhieuMuon;



SELECT MaSach
FROM SACH
WHERE MaSach IN (
    SELECT MaSach, COUNT(MaSach)
FROM ChiTietPhieuMuon
GROUP BY MaSach

)
GROUP BY MaSach;

UPDATE Sach
SET SoLuong = SoLuong - 1 WHERE MaSach in (
        SELECT MaSach
FROM ChiTietPhieuMuon
WHERE MaPhieuMuon = 1
)

SELECT MaSach, COUNT(MaSach) AS SoLuongMuon
FROM ChiTietPhieuMuon
GROUP BY MaSach

INSERT INTO ChiTietPhieuMuon
    (MaPhieuMuon, MaSach, NgayTraDuKien, NgayTraThucTe, TrangThaiMuon, TrangThaiSach)
VALUES
    (1, 5, '2024-02-10 00:00:00.0000000', '2024-02-08 00:00:00.0000000', N'Đang mượn', N'Tốt'),
    (2, 5, '2024-02-10 00:00:00.0000000', '2024-02-08 00:00:00.0000000', N'Đang mượn', N'Tốt');

SELECT *
FROM Sach
WHERE MaSach = 4;

SELECT *
FROM ChiTietPhieuMuon
WHERE MaPhieuMuon = 3;



UPDATE ChiTietPhieuMuon
SET TrangThaiMuon = N'Đang mượn', TrangThaiSach = N'Tốt'
WHERE MaPhieuMuon = 1 AND MaSach = 4;

UPDATE ChiTietPhieuMuon
SET TrangThaiMuon = N'Đã trả', TrangThaiSach = N'Tốt'
WHERE MaPhieuMuon = 1 AND MaSach = 4;

