USE QuanLyThuVienDB;
GO

SELECT *
FROM PhieuMuon;

SELECT *
FROM Sach;

SELECT *
FROM ChiTietPhieuMuon;


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




IF EXISTS (SELECT 1
FROM deleted)
    BEGIN

    UPDATE ct
        SET ct.MaPhieuMuon = i.MaPhieuMuon,
            ct.MaSach = i.MaSach,
            ct.NgayTraDuKien = i.NgayTraDuKien,
            ct.NgayTraThucTe = i.NgayTraThucTe,
            ct.TrangThaiMuon = i.TrangThaiMuon,
            ct.TrangThaiSach = i.TrangThaiSach
        FROM ChiTietPhieuMuon ct
        JOIN inserted i ON ct.MaPhieuMuon = i.MaPhieuMuon;
    RETURN
END
