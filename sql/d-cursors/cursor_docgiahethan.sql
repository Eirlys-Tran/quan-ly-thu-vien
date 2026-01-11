

DECLARE @MaDocGia INT
DECLARE @NgayHetHan DATETIME2(7)
DECLARE @MaThe INT
DECLARE @SoNgayQuaHan INT

-- Khai báo cursor
DECLARE DocGiaHetHan CURSOR FOR
select dg.MaDocGia, ttv.NgayHetHan, ttv.MaThe
from DocGia dg
join TheThuVien ttv
on dg.MaDocGia = ttv.MaDocGia

OPEN DocGiaHetHan

FETCH NEXT FROM DocGiaHetHan INTO @MaDocGia, @NgayHetHan, @MaThe

WHILE @@FETCH_STATUS = 0
BEGIN
	-- logic check doc gia qua han va in thong bao
	-- Kiểm tra thẻ hết hạn
    IF @NgayHetHan < GETDATE()
    BEGIN
        SET @SoNgayQuaHan = DATEDIFF(DAY, @NgayHetHan, GETDATE())

        -- In thông báo
        PRINT 
          N'Độc giả ' + CAST(@MaDocGia AS NVARCHAR) +
          N' (Mã thẻ ' + CAST(@MaThe AS NVARCHAR) + 
          N') đã quá hạn ' + CAST(@SoNgayQuaHan AS NVARCHAR) + N' ngày'
    END
   
  
	FETCH NEXT FROM DocGiaHetHan INTO @MaDocGia, @NgayHetHan, @MaThe

END

CLOSE DocGiaHetHan
DEALLOCATE DocGiaHetHan
