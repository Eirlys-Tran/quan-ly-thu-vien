-- Kiểm tra cccd và sdt: Ngăn insert/update CCCD và SDT bị trùng lặp trong bảng DOCGIA và NHANVIEN

USE QuanLyThuVienDB;
GO

IF OBJECT_ID('dbo.c6_KiemTraCCCDVaSoDienThoaiDocGia', 'TR') IS NOT NULL
    DROP TRIGGER dbo.c6_KiemTraCCCDVaSoDienThoaiDocGia;
GO

CREATE TRIGGER c6_KiemTraCCCDVaSoDienThoaiDocGia
ON dbo.DocGia
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
    FROM inserted i
        JOIN dbo.DocGia d ON i.CCCD = d.CCCD OR i.SoDienThoai = d.SoDienThoai
    )
    BEGIN
        RAISERROR(N'CCCD hoặc số điện thoại đã tồn tại', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    INSERT INTO DocGia
        (
        MaDocGia,
        HoTen,
        NgaySinh,
        DiaChi,
        CCCD,
        SoDienThoai,
        Username,
        Password,
        TrangThai
        )
    SELECT MaDocGia,
        HoTen,
        NgaySinh,
        DiaChi,
        CCCD,
        SoDienThoai,
        Username,
        Password,
        TrangThai
    FROM inserted;
END
GO


IF OBJECT_ID('dbo.c6_KiemTraCCCDVaSoDienThoaiNhanVien', 'TR') IS NOT NULL
    DROP TRIGGER dbo.c6_KiemTraCCCDVaSoDienThoaiNhanVien;
GO

CREATE TRIGGER c6_KiemTraCCCDVaSoDienThoaiNhanVien
ON dbo.NhanVien
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
    FROM inserted i
        JOIN dbo.NhanVien d ON i.CCCD = d.CCCD OR i.SoDienThoai = d.SoDienThoai
    )
    BEGIN
        RAISERROR(N'CCCD hoặc số điện thoại đã tồn tại', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    INSERT INTO NhanVien
        (
        MaNhanVien,
        HoTen,
        NgaySinh,
        DiaChi,
        CCCD,
        SoDienThoai,
        Username,
        Password,
        TrangThai
        )
    SELECT MaNhanVien,
        HoTen,
        NgaySinh,
        DiaChi,
        CCCD,
        SoDienThoai,
        Username,
        Password,
        TrangThai
    FROM inserted;
END
GO