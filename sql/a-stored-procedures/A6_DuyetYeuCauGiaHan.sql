CREATE PROCEDURE sp_DuyetYeuCauGiaHan
    @MaYeuCauGiaHan INT,
    @ChapNhan BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaPhieuMuon INT, @MaSach INT, @NgayGiaHan DATETIME2;

    SELECT
        @MaPhieuMuon = MaPhieuMuon,
        @MaSach = MaSach,
        @NgayGiaHan = NgayGiaHan
    FROM YeuCauGiaHan
    WHERE MaYeuCauGiaHan = @MaYeuCauGiaHan;

    IF @ChapNhan = 1
    BEGIN
        -- Cập nhật ngày trả
        UPDATE ChiTietPhieuMuon
        SET NgayTraDuKien = @NgayGiaHan
        WHERE MaPhieuMuon = @MaPhieuMuon
          AND MaSach = @MaSach;

        -- Cập nhật trạng thái
        UPDATE YeuCauGiaHan
        SET TrangThai = N'Đã duyệt'
        WHERE MaYeuCauGiaHan = @MaYeuCauGiaHan;
    END
    ELSE
    BEGIN
        UPDATE YeuCauGiaHan
        SET TrangThai = N'Từ chối'
        WHERE MaYeuCauGiaHan = @MaYeuCauGiaHan;
    END
END
