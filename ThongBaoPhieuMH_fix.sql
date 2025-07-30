CREATE OR ALTER PROCEDURE ThongBaoPhieuMH
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE @thangHienTai INT;
    SET @thangHienTai = MONTH(GETDATE());

    DECLARE @sdt INT;
    DECLARE @loaiKH NVARCHAR(50);
    DECLARE @uuDai INT;

    DECLARE customerCursor CURSOR STATIC LOCAL FORWARD_ONLY READ_ONLY FOR
        SELECT KhachHang.SDT, KhachHang.LoaiKH, LoaiKhachHang.UuDai
        FROM KhachHang
                 JOIN LoaiKhachHang ON KhachHang.LoaiKH = LoaiKhachHang.Ten
        WHERE MONTH(NgaySinh) = @thangHienTai;

    OPEN customerCursor;

    WHILE 1 = 1
        BEGIN
            BEGIN TRANSACTION;
            BEGIN TRY
                -- FETCH bên trong transaction để bảo vệ dòng dữ liệu
                FETCH NEXT FROM customerCursor INTO @sdt, @loaiKH, @uuDai;
                IF @@FETCH_STATUS <> 0
                    BEGIN
                        COMMIT TRANSACTION;
                        BREAK; -- Thoát vòng lặp nếu hết dữ liệu
                    END;
                exec ThayDoiVoucher @sdt, 1;
                -- Xử lý thông báo
                DECLARE @message NVARCHAR(225);
                SET @message = N'Mừng tháng sinh nhật, tặng bạn phiếu mua hàng trị giá: ' + CAST(@uuDai AS NVARCHAR) + N' đồng.';
                PRINT @message;
                
                COMMIT TRANSACTION;
            END TRY
            BEGIN CATCH
                -- Rollback nếu có lỗi
                ROLLBACK TRANSACTION;
                PRINT ERROR_MESSAGE();
                BREAK; -- Thoát vòng lặp nếu xảy ra lỗi
            END CATCH;
        END;

    CLOSE customerCursor;
    DEALLOCATE customerCursor;
END;
GO