USE [supermarket_HQTCSDL]
GO
/****** Object:  StoredProcedure [dbo].[DatHang]    Script Date: 1/11/2025 10:54:34 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[DatHang]
    @ID_HTK INT,
    @SL INT
AS
BEGIN
    INSERT INTO DonDatHang (SL, SLDuocGiao, NgayDat, TrangThai, IDHTK)
    VALUES (@SL, 0, getdate(), N'Chưa giao',@ID_HTK);
END;
