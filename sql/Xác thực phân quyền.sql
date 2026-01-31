
/* =========================================================
   1. TẠO LOGIN (SERVER LEVEL)
   ========================================================= */

-- Login Nhân viên thư viện
CREATE LOGIN login_nhanvien
WITH PASSWORD = 'Nv@123456',
     CHECK_POLICY = ON;

-- Login Độc giả
CREATE LOGIN login_docgia
WITH PASSWORD = 'Dg@123456',
     CHECK_POLICY = ON;


/* =========================================================
   2. TẠO USER TRONG DATABASE
   ========================================================= */

USE QuanLyThuVienDB;
GO

-- User Nhân viên
CREATE USER user_nhanvien FOR LOGIN login_nhanvien;

-- User Độc giả
CREATE USER user_docgia FOR LOGIN login_docgia;


/* =========================================================
   3. TẠO DATABASE ROLE
   ========================================================= */

CREATE ROLE role_nhanvien;   -- Vai trò Nhân viên thư viện
CREATE ROLE role_docgia;     -- Vai trò Độc giả


/* =========================================================
   4. GÁN USER VÀO ROLE
   ========================================================= */

ALTER ROLE role_nhanvien ADD MEMBER user_nhanvien;
ALTER ROLE role_docgia ADD MEMBER user_docgia;


/* =========================================================
   5. PHÂN QUYỀN CHO NHÂN VIÊN THƯ VIỆN
   ========================================================= */

-- 5.1 Quản lý mượn – trả sách
-- Phiếu mượn
GRANT SELECT, INSERT, UPDATE
ON PhieuMuon TO role_nhanvien;

-- Chi tiết phiếu mượn
GRANT SELECT, INSERT, UPDATE
ON ChiTietPhieuMuon TO role_nhanvien;

-- Hóa đơn
GRANT SELECT, INSERT, UPDATE
ON HoaDon TO role_nhanvien;

-- Sách
GRANT SELECT, INSERT, UPDATE ON Sach TO role_nhanvien;

-- Độc giả
GRANT SELECT, INSERT, UPDATE ON DocGia TO role_nhanvien;

-- Nhân viên
GRANT SELECT, INSERT, UPDATE ON NhanVien TO role_nhanvien;

-- Thể loai sách
GRANT SELECT, INSERT, UPDATE ON Theloai TO role_nhanvien;

-- Thẻ thư viện
GRANT SELECT, INSERT, UPDATE ON TheThuVien TO role_nhanvien;


-- 5.4 Không cho xóa dữ liệu nghiệp vụ
DENY DELETE ON PhieuMuon TO role_nhanvien;
DENY DELETE ON ChiTietPhieuMuon TO role_nhanvien;
DENY DELETE ON HoaDon TO role_nhanvien;
DENY DELETE ON Sach TO role_nhanvien;
DENY DELETE ON DocGia TO role_nhanvien;
DENY DELETE ON Theloai TO role_nhanvien;
DENY DELETE ON TheThuVien TO role_nhanvien;
DENY DELETE ON NhanVien TO role_nhanvien;

-- 5.5 Giới hạn UPDATE (chỉ cập nhật mượn – trả)
REVOKE UPDATE ON PhieuMuon FROM role_nhanvien;

GRANT UPDATE (NgayLap)
ON PhieuMuon TO role_nhanvien;


/* =========================================================
   6. PHÂN QUYỀN CHO ĐỘC GIẢ
   ========================================================= */

-- 6.1 View sách công khai
-- Thẻ thư viện
DENY DELETE, SELECT, INSERT, UPDATE ON TheThuVien TO role_docgia;

GRANT SELECT
ON vw_TheThuVien TO role_docgia;

-- Độc giả

DENY DELETE, SELECT, INSERT, UPDATE ON DocGia TO role_docgia;

GRANT SELECT (Username, Password)
ON DocGia
TO role_docgia;

GRANT UPDATE (HoTen, NgaySinh, DiaChi, SoDienThoai, CCCD, Password)
ON DocGia TO role_docgia;

GRANT SELECT
ON vw_Docgia TO role_docgia;

-- Phiểu mượn
GRANT INSERT ON PhieuMuon TO role_docgia;
DENY DELETE, SELECT, UPDATE ON PhieuMuon TO role_docgia;

GRANT SELECT
ON vw_Docgia TO role_docgia;

-- Chi tiêt phiếu mượn
GRANT INSERT ON CHITIETPHIEUMUON TO role_docgia;
DENY DELETE, SELECT, UPDATE ON ChiTietPhieuMuon TO role_docgia;
GRANT SELECT
ON vw_PhieuMuon TO role_docgia;

GRANT UPDATE (NgayTraDuKien)
ON ChiTietPhieuMuon TO role_docgia;
-- Sach
DENY DELETE, SELECT, INSERT, UPDATE ON Sach TO role_docgia;
GRANT SELECT
ON vw_Sach_Public TO role_docgia;
