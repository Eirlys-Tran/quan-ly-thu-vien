CREATE PROCEDURE sp_CapNhatTaiKhoan
    @Username NVARCHAR(45),
    @PasswordMoi NVARCHAR(255) = NULL,
    @TrangThaiMoi NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Cập nhật Nhân viên
    IF EXISTS (SELECT 1 FROM NhanVien WHERE Username = @Username)
    BEGIN
        UPDATE NhanVien
        SET
            Password = ISNULL(@PasswordMoi, Password),
            TrangThai = ISNULL(@TrangThaiMoi, TrangThai)
        WHERE Username = @Username;
        RETURN;
    END

    -- Cập nhật Độc giả
    IF EXISTS (SELECT 1 FROM DocGia WHERE Username = @Username)
    BEGIN
        UPDATE DocGia
        SET
            Password = ISNULL(@PasswordMoi, Password),
            TrangThai = ISNULL(@TrangThaiMoi, TrangThai)
        WHERE Username = @Username;
        RETURN;
    END
END
