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

SELECT *
FROM ChiTietPhieuMuon;

SELECT *
FROM YeuCauGiaHan;

SELECT Y.MaYeuCauGiaHan, Y.MaPhieuMuon, Y.MaSach, Y.NgayTao, Y.NgayGiaHan, Y.TrangThai
FROM ChiTietPhieuMuon C JOIN YeuCauGiaHan Y ON C.MaPhieuMuon = Y.MaPhieuMuon AND C.MaSach = Y.MaSach
WHERE C.MaPhieuMuon = 13 AND C.MaSach = 7;

INSERT INTO YeuCauGiaHan
    (MaPhieuMuon, MaSach, NgayTao, NgayGiaHan, TrangThai)
VALUES
    (13, 7, '2024-02-10 00:00:00.0000000', '2024-02-08 00:00:00.0000000', N'Đã duyệt');


SELECT P.MaThe, COUNT(*)
FROM ChiTietPhieuMuon C JOIN PhieuMuon P ON C.MaPhieuMuon = P.MaPhieuMuon
    JOIN TheThuVien T ON P.MaThe = T.MaThe
WHERE C.TrangThaiMuon = N'Đang mượn'
GROUP BY P.MaThe