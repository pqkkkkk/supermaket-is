USE [supermarket_HQTCSDL]
GO
/****** Object:  StoredProcedure [dbo].[ThongKeTuyChon]    Script Date: 1/11/2025 11:04:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[ThongKeTuyChon] (
    @kieuThongKe NVARCHAR(10),
    @ngayBatDau DATE,
    @ngayKetThuc DATETIME = NULL,
    @DT FLOAT OUTPUT,
    @SLKH INT OUTPUT
)
AS
BEGIN
    SET @DT = 0;
    SET @SLKH = 0;


    BEGIN TRANSACTION;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    BEGIN TRY
        -- 1. kiểm tra kiểu thống kê
        IF @kieuThongKe NOT IN ('TUAN', 'THANG', 'KHOANG')
            BEGIN
                PRINT N'Lỗi: Kiểu thống kê không hợp lệ.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

        -- xử lý để @ngayBatDau về đầu tuần.
        IF @kieuThongKe = 'TUAN'
            BEGIN
                -- DATEPART(WEEKDAY, @ngayBatDau): xác định ngày trong tuần
                -- @@DATEFIRST: ngày đầu tuần (mặc định là Chủ Nhật)
                SET @ngayBatDau = DATEADD(DAY, 2 - DATEPART(WEEKDAY, @ngayBatDau), @ngayBatDau);
				SET @ngayKetThuc = DATEADD(DAY, 6, @ngayBatDau);
				PRINT N'Ngày đầu tuần: ' + CAST(@ngayBatDau AS NVARCHAR);
				PRINT N'Ngày cuối tuần: ' + CAST(@ngayKetThuc AS NVARCHAR);
            END
        -- 2. tính tổng doanh thu và số lượng khách hàng
        IF @kieuThongKe = 'TUAN'
            BEGIN
                SELECT
                    @DT = ISNULL(SUM(TongTien),0),
                    @SLKH = ISNULL(COUNT(DISTINCT IDKH), 0)
                FROM DonHang
                WHERE NgayMua BETWEEN @ngayBatDau AND DATEADD(DAY, 6, @ngayBatDau); -- tìm ra tuần cần thống kê dựa trên ngày bắt đầu
            END
        ELSE IF @kieuThongKe = 'THANG'
            BEGIN
			-- Xác định ngày đầu tháng
                DECLARE @ngayDauThang DATE;
                SET @ngayDauThang = DATEFROMPARTS(YEAR(@ngayBatDau), MONTH(@ngayBatDau), 1);

				PRINT N'Tháng thống kê: ' + CAST(MONTH(@ngayDauThang) AS NVARCHAR) + N'-' + CAST(YEAR(@ngayDauThang) AS NVARCHAR);
                PRINT N'Ngày bắt đầu của tháng: ' + CAST(@ngayDauThang AS NVARCHAR);

                SELECT
                    @DT = ISNULL(SUM(TongTien),0),
                    @SLKH = ISNULL(COUNT(DISTINCT IDKH), 0)
                FROM DonHang
                WHERE MONTH(NgayMua) = MONTH(@ngayBatDau) AND YEAR(NgayMua) = YEAR(@ngayBatDau); -- Tính tháng
            END
        ELSE IF @kieuThongKe = 'KHOANG'
            BEGIN
				IF @ngayKetThuc IS NULL
				BEGIN
					PRINT N'Lỗi: Ngày kết thúc không được để trống khi thống kê theo khoảng.';
					ROLLBACK TRANSACTION;
					RETURN;
					END
					-- Print ngày bắt đầu và ngày kết thúc
                PRINT N'Ngày bắt đầu: ' + CAST(@ngayBatDau AS NVARCHAR);
                PRINT N'Ngày kết thúc: ' + CAST(@ngayKetThuc AS NVARCHAR);
                SELECT
                    @DT = ISNULL(SUM(TongTien),0),
                    @SLKH = ISNULL(COUNT(DISTINCT IDKH), 0)
                FROM DonHang
                WHERE NgayMua BETWEEN @ngayBatDau AND @ngayKetThuc; -- Tính khoảng thời gian
            END

        -- Commit transaction
        COMMIT TRANSACTION;

        -- in kết quả
        PRINT N'Thống kê hoàn tất.';
        PRINT N'Tổng doanh thu: ' + FORMAT(@DT, 'N2');
        PRINT N'Tổng số lượng khách hàng: ' + CAST(@SLKH AS NVARCHAR);
    END TRY
    BEGIN CATCH
        -- Rollback nếu xảy ra lỗi
        ROLLBACK TRANSACTION;
        PRINT N'Lỗi xảy ra: ' + ERROR_MESSAGE();
    END CATCH;
END;