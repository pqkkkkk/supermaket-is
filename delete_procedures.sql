-- Tạo một script để xóa tất cả Stored Procedures
DECLARE @procName NVARCHAR(MAX);

-- Lặp qua tất cả các Stored Procedures trong database hiện tại
DECLARE proc_cursor CURSOR FOR
SELECT [name]
FROM sys.objects
WHERE type = 'P' -- 'P' là loại object cho Stored Procedures
      AND is_ms_shipped = 0; -- Bỏ qua các hệ thống Stored Procedures của SQL Server

OPEN proc_cursor;

FETCH NEXT FROM proc_cursor INTO @procName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Tạo lệnh DROP PROCEDURE
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = 'DROP PROCEDURE [' + @procName + ']';
    PRINT @sql; -- In ra lệnh (tùy chọn)
    EXEC sp_executesql @sql; -- Thực thi lệnh
    
    FETCH NEXT FROM proc_cursor INTO @procName;
END;

CLOSE proc_cursor;
DEALLOCATE proc_cursor;
