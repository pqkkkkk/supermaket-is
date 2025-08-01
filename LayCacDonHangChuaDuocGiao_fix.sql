USE [supermarket_HQTCSDL]
GO
/****** Object:  StoredProcedure [dbo].[LayCacDonHangChuaDuocGiao]    Script Date: 1/11/2025 10:28:17 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Bo phan quan ly kho hang
ALTER PROCEDURE [dbo].[LayCacDonHangChuaDuocGiao]
    @ID_HTK INT,
    @SLCDG INT OUTPUT
AS
BEGIN
    SELECT @SLCDG = ISNULL(SUM(SL), 0)
    FROM DonDatHang
    WHERE IDHTK = @ID_HTK AND TrangThai = N'Chưa giao';
END;
