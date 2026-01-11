-- Giới hạn số lượng sách mượn: Ngăn không cho một độc giả mượn thêm sách nếu tổng số sách họ đang mượn (trạng thái 'Đang mượn') cộng với số sách trong lần mượn mới vượt quá 5 cuốn.

USE QuanLyThuVienDB;
GO

IF OBJECT_ID('dbo.c4_GioiHanSoSachMuon', 'TR') IS NOT NULL
    DROP TRIGGER dbo.c4_GioiHanSoSachMuon;
GO

CREATE TRIGGER c4_GioiHanSoSachMuon
ON dbo.ChiTietPhieuMuon
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
    FROM inserted i
        JOIN dbo.PhieuMuon p ON i.MaPhieuMuon = p.MaPhieuMuon
    GROUP BY p.MaThe
    HAVING (
            -- Số lượng sách mới
            COUNT(i.MaSach)
            +
            -- Số lượng sách đang mượn bởi khách hàng
            (
                SELECT ISNULL(COUNT(*), 0)
    FROM dbo.ChiTietPhieuMuon c2
        JOIN dbo.PhieuMuon p2 ON c2.MaPhieuMuon = p2.MaPhieuMuon
    WHERE p2.MaThe = p.MaThe AND c2.TrangThaiMuon = N'Đang mượn'
            )
        ) > 5
    )
    BEGIN
        RAISERROR(N'Số lượng sách mượn vượt quá giới hạn 5 cuốn cho một hoặc nhiều độc giả.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- If the check passes, perform the actual insert.
    INSERT INTO ChiTietPhieuMuon
        (MaPhieuMuon, MaSach, NgayTraDuKien, NgayTraThucTe, TrangThaiMuon, TrangThaiSach)
    SELECT MaPhieuMuon, MaSach, NgayTraDuKien, NgayTraThucTe, TrangThaiMuon, TrangThaiSach
    FROM inserted;
END