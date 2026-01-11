

DECLARE @MaSach INT
DECLARE @TenSach NVARCHAR(150)
DECLARE @SoLanMuon INT

-- Khai báo cursor
DECLARE SoLanMuon CURSOR FOR
select s.MaSach, s.TenSach, COUNT(ctpm.MaPhieuMuon) as SoLanMuon
from Sach s
left join ChiTietPhieuMuon ctpm
on s.MaSach = ctpm.MaSach
group by s.MaSach, s.TenSach

OPEN SoLanMuon

FETCH NEXT FROM SoLanMuon INTO @MaSach, @TenSach, @SoLanMuon

WHILE @@FETCH_STATUS = 0
BEGIN
	-- logic check SoLanMuon
	
    IF @SoLanMuon < 2 
    BEGIN
        -- In thông báo
        PRINT N'Sách "' + @TenSach + 
              N'" (Mã sách: ' + CAST(@MaSach AS NVARCHAR) +
              N') ít được mượn – Số lần mượn: ' + 
              CAST(@SoLanMuon AS NVARCHAR)
    END
FETCH NEXT FROM SoLanMuon INTO @MaSach, @TenSach, @SoLanMuon

END

CLOSE SoLanMuon
DEALLOCATE SoLanMuon

