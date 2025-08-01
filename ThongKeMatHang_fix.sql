USE [supermarket_HQTCSDL]
GO
/****** Object:  StoredProcedure [dbo].[ThongKeMatHang]    Script Date: 1/11/2025 10:03:24 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[ThongKeMatHang]
    @ID_HTK INT,
    @KQ INT OUTPUT
AS
BEGIN
    DECLARE @SLSPTK INT, @SLSPTD INT, @SLCDG INT, @SL INT;

    SELECT @SLSPTK = htk.SPSPTK
    FROM HangTrongKho htk
    WHERE htk.IDSP = @ID_HTK;

    SELECT @SLSPTD = htk.SLSPTD
    FROM HangTrongKho htk
    WHERE htk.IDSP = @ID_HTK;

    EXEC LayCacDonHangChuaDuocGiao @ID_HTK, @SLCDG OUTPUT;

	PRINT 'SL san pham toi da: ' + CAST(@SLSPTD as nvarchar);
	PRINT 'SL san pham ton kho: ' + CAST(@SLSPTK as nvarchar);
	PRINT 'SL san pham chua duoc giao: ' + CAST(@SLCDG as nvarchar);

    SET @SL = @SLSPTK + @SLCDG;

    IF @SL < 0.7 * @SLSPTD
        SET @KQ = @SLSPTD - @SL;
    ELSE
        SET @KQ = 0;
END;
