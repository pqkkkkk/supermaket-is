USE [supermarket_HQTCSDL]
GO
/****** Object:  StoredProcedure [dbo].[KiemTraKho]    Script Date: 1/11/2025 9:40:31 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[KiemTraKho]
AS
BEGIN
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRAN;
    DECLARE @IDSP INT;
    DECLARE MatHangCursor CURSOR LOCAL FOR SELECT IDSP FROM HangTrongKho;

    OPEN MatHangCursor;
    FETCH NEXT FROM MatHangCursor INTO @IDSP;
    WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @SLCanDat INT;
            EXEC ThongKeMatHang @IDSP, @SLCanDat OUTPUT;
            IF (@SLCanDat > 0)
                BEGIN
					PRINT 'SL can dat cua sp' + CAST(@IDSP AS NVARCHAR) + 'la: ' + CAST(@SLCanDat AS NVARCHAR);
					PRINT ('Dat hang san pham nay');
                    EXEC DatHang @IDSP, @SLCanDat;
                END;
			ELSE
				BEGIN
					PRINT 'SL can dat cua sp' + CAST(@IDSP AS NVARCHAR) + 'la: ' + CAST(@SLCanDat AS NVARCHAR);
					PRINT('Khong can dat hang sp nay');
				END;
        FETCH NEXT FROM MatHangCursor INTO @IDSP;
    END;

    CLOSE MatHangCursor;
    DEALLOCATE MatHangCursor;
COMMIT;
END;
