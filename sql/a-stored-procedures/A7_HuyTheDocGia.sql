CREATE PROCEDURE sp_HuyTheDocGia
    @MaDocGia INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Kiểm tra còn sách đang mượn hoặc trễ hạn không
    IF EXISTS (
        SELECT 1
        FROM ChiTietPhieuMuon ct
        JOIN PhieuMuon pm ON ct.MaPhieuMuon = pm.MaPhieuMuon
        JOIN TheThuVien t ON pm.MaThe = t.MaThe
        WHERE t.MaDocGia = @MaDocGia
          AND ct.TrangThaiMuon IN (N'Đang mượn', N'Trễ hạn')
    )
    BEGIN
        RAISERROR (N'Không thể hủy thẻ: độc giả vẫn còn sách chưa trả', 16, 1);
        RETURN;
    END

    -- Hủy thẻ thư viện
    UPDATE TheThuVien
    SET TrangThai = N'Bị hủy'
    WHERE MaDocGia = @MaDocGia;

    -- Vô hiệu tài khoản độc giả
    UPDATE DocGia
    SET TrangThai = N'Vô hiệu'
    WHERE MaDocGia = @MaDocGia;
END
