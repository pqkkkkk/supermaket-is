DECLARE @sql NVARCHAR(MAX);

-- Tạo script DROP TYPE
SET @sql = (
    SELECT STRING_AGG('DROP TYPE [' + SCHEMA_NAME(schema_id) + '].[' + name + '];', CHAR(13))
    FROM sys.types
    WHERE is_user_defined = 1
);

-- Thực thi script DROP TYPE
EXEC sp_executesql @sql;
