-- Bo phan quan ly kho hang
CREATE PROCEDURE LayCacDonHangChuaDuocGiao
    @ID_HTK INT,
    @SLCDG INT OUTPUT
AS
BEGIN
    SELECT @SLCDG = ISNULL(SUM(SL),0)
    FROM DonDatHang
    WHERE IDHTK = @ID_HTK AND TrangThai = N'Chưa giao';
END;
GO
CREATE PROCEDURE ThongKeMatHang
    @ID_HTK INT,
    @KQ INT OUTPUT
AS
BEGIN
    DECLARE @SLSPTK INT, @SLSPTD INT, @SLCDG INT, @SL INT

    SELECT @SLSPTK = htk.SPSPTK
    FROM HangTrongKho htk
    WHERE htk.IDSP = @ID_HTK;

    SELECT @SLSPTD = htk.SLSPTD
    FROM HangTrongKho htk
    WHERE htk.IDSP = @ID_HTK;

    EXEC LayCacDonHangChuaDuocGiao @ID_HTK, @SLCDG OUTPUT;
        SET @SL = @SLSPTK + @SLCDG;

        IF @SL < 0.7 * @SLSPTD
            SET @KQ = @SLSPTD - @SL;
        ELSE
            SET @KQ = 0;
END;
go
CREATE PROCEDURE DatHang
    @ID_HTK INT,
    @SL INT
AS
BEGIN
    INSERT INTO DonDatHang (SL, SLDuocGiao, NgayDat, TrangThai, IDHTK)
    VALUES (@SL, 0, getdate(), N'Chưa Giao',@ID_HTK);
END;
go
CREATE PROCEDURE KiemTraKho
AS
BEGIN
	BEGIN TRY
		SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
		BEGIN TRAN;
			DECLARE @IDSP INT;
			DECLARE MatHangCursor CURSOR LOCAL FOR SELECT IDSP FROM HangTrongKho;

			OPEN MatHangCursor;
			FETCH NEXT FROM MatHangCursor INTO @IDSP;
			WHILE @@FETCH_STATUS = 0
				BEGIN
					PRINT '-------------------------------------';
					PRINT 'San pham ' + CAST (@IDSP AS NVARCHAR);
					DECLARE @SLCanDat INT;
					EXEC ThongKeMatHang @IDSP, @SLCanDat OUTPUT;
					IF (@SLCanDat > 0)
						BEGIN
							EXEC DatHang @IDSP, @SLCanDat;
							PRINT 'SL can dat cua sp ' + CAST(@IDSP AS NVARCHAR) + ' la: ' + CAST(@SLCanDat AS NVARCHAR);
							PRINT ('Dat hang san pham nay');
						END;
					ELSE
						BEGIN
							PRINT 'SL can dat cua sp ' + CAST(@IDSP AS NVARCHAR) + ' la: ' + CAST(@SLCanDat AS NVARCHAR);
							PRINT('Khong can dat hang sp nay');
						END;
				FETCH NEXT FROM MatHangCursor INTO @IDSP;
			END;

			CLOSE MatHangCursor;
			DEALLOCATE MatHangCursor;
		COMMIT;
	END TRY

	BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        PRINT 'Error occurred!';
        PRINT ERROR_MESSAGE();
    END CATCH
END;
go
CREATE TYPE DSCTDGH AS TABLE(
	IDDDH int,
	SL int
)
GO
CREATE PROCEDURE ThemDonGiaoHang
    @DS_DDH DSCTDGH READONLY
AS
BEGIN
	BEGIN TRY
		SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
		BEGIN TRAN;

		DECLARE @ID_DGH INT;

		INSERT INTO DonGiaoHang (NgayGiao, TrangThai)
		VALUES (GETDATE(), N'Đã Giao');

		SET @ID_DGH = SCOPE_IDENTITY();
		DECLARE @IDDDH INT;
		DECLARE @SoLuong INT;

		DECLARE DonDatHangCursor CURSOR LOCAL FOR
		SELECT IDDDH, SL FROM @DS_DDH;

		OPEN DonDatHangCursor;
		FETCH NEXT FROM DonDatHangCursor INTO @IDDDH, @SoLuong;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			UPDATE DonDatHang
			SET SLDuocGiao = @SoLuong,
				TrangThai = N'Đã giao',
				IDDGH = @ID_DGH
			WHERE ID = @IDDDH;

			DECLARE @IDHTK INT;
			SELECT @IDHTK = IDHTK FROM DonDatHang WHERE ID = @IDDDH;
			UPDATE HangTrongKho
			SET HangTrongKho.SPSPTK = HangTrongKho.SPSPTK + @SoLuong
			WHERE IDSP = @IDHTK;

			EXEC CapNhatTrangThaiSanPhamKhuyenMai @IDHTK;

			FETCH NEXT FROM DonDatHangCursor INTO @IDDDH, @SoLuong;
		END;

		CLOSE DonDatHangCursor;
		DEALLOCATE DonDatHangCursor;
		COMMIT;
	END TRY

	BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        PRINT 'Error occurred!';
        PRINT ERROR_MESSAGE(); 
    END CATCH
END;
go
-- Bo phan cham soc khach hang
CREATE PROCEDURE PhanHangKH
AS
BEGIN

    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    DECLARE @sdt varchar(15);
    DECLARE @tongTienMua INT;
    DECLARE @loaiKH NVARCHAR(50);
    DECLARE @nguongTren INT;

    DECLARE customerCursor CURSOR DYNAMIC LOCAL FORWARD_ONLY FOR
        SELECT SDT, TongTienMua, LoaiKH
        FROM KhachHang
        FOR UPDATE OF LoaiKH;

    OPEN customerCursor;

    WHILE 1 = 1
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                -- FETCH bên trong transaction để bảo vệ dòng dữ liệu
                FETCH NEXT FROM customerCursor INTO @sdt, @tongTienMua, @loaiKH;
                IF @@FETCH_STATUS <> 0
                    BEGIN
                        COMMIT TRANSACTION;
                        BREAK; -- Thoát vòng lặp nếu hết dữ liệu
                    END;

                -- Lấy thông tin phân hạng khách hàng và ngưỡng chi tiêu phù hợp
                SELECT TOP 1 @loaiKH = Ten, @nguongTren = NguongTren
                FROM LoaiKhachHang
                WHERE @tongTienMua >= NguongTren
                ORDER BY NguongTren DESC;

                -- Cập nhật phân hạng cho khách hàng
                UPDATE KhachHang
                SET LoaiKH = @loaiKH
                WHERE CURRENT OF customerCursor;

                COMMIT TRANSACTION;
            END TRY

            BEGIN CATCH
				-- Nếu có lỗi, SQL Server sẽ nhảy vào đây
				IF @@TRANCOUNT > 0
				BEGIN
					ROLLBACK TRANSACTION;
				END

				-- Thông báo lỗi
				PRINT 'Error occurred!';
				PRINT ERROR_MESSAGE(); -- Lấy thông tin lỗi
			END CATCH
        END;

    CLOSE customerCursor;
    DEALLOCATE customerCursor;
END;
GO
CREATE PROCEDURE ThongBaoPhieuMH
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE @thangHienTai INT;
    SET @thangHienTai = MONTH(GETDATE());

    DECLARE @sdt varchar(15);
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
            BEGIN TRY
                BEGIN TRANSACTION;
            
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
				-- Nếu có lỗi, SQL Server sẽ nhảy vào đây
				IF @@TRANCOUNT > 0
				BEGIN
					ROLLBACK TRANSACTION;
				END

				-- Thông báo lỗi
				PRINT 'Error occurred!';
				PRINT ERROR_MESSAGE(); -- Lấy thông tin lỗi
			END CATCH
        END;

    CLOSE customerCursor;
    DEALLOCATE customerCursor;
END;
GO
CREATE PROCEDURE ThayDoiVoucher
    @sdt varchar(15),
    @trangThaiVoucher INT
AS
BEGIN
    UPDATE KhachHang
    SET Voucher = @trangThaiVoucher
    WHERE SDT = @sdt;
END;
GO
CREATE PROCEDURE TaoTKKH
    @sdt varchar(15),
    @ngaySinh DATE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM KhachHang WHERE SDT = @sdt)
        BEGIN
            PRINT N'Khách hàng đã có tài khoản';
            RETURN;
        END

    INSERT INTO KhachHang (SDT, NgaySinh, NgayDangKy, TongTienMua, LoaiKH, Voucher)
    VALUES (@sdt, @ngaySinh, GETDATE(), 0, N'Thân thiết', 0);

    PRINT N'Tạo tài khoản thành công';
END;
GO
CREATE PROCEDURE XoaTKKH
@sdt varchar(15)
AS
BEGIN
    -- Kiểm tra tài khoản có tồn tại không
    IF NOT EXISTS (SELECT 1 FROM KhachHang WHERE SDT = @sdt)
        BEGIN
            PRINT N'Không tìm thấy khách hàng với số điện thoại này.';
            RETURN;
        END

    -- Xóa thông tin khách hàng từ bảng Khach_Hang
    DELETE FROM KhachHang WHERE SDT = @sdt;

    PRINT N'Đã xóa tài khoản thành công';
END;
go
CREATE PROCEDURE CapNhatThongTinKhachHang
    @sdt varchar(15),
    @ngaySinh DATE = NULL,
    @tongTienMua INT = NULL
AS
BEGIN
    -- Kiểm tra tài khoản cần cập nhật đã tồn tại hay chưa
    IF NOT EXISTS (SELECT 1 FROM KhachHang WHERE SDT = @sdt)
        BEGIN
            PRINT N'Không tìm thấy tài khoản với số điện thoại này!';
            RETURN;
        END

    -- Cập nhật thông tin ngày sinh nếu không NULL
    IF @ngaySinh IS NOT NULL
        BEGIN
            UPDATE KhachHang
            SET NgaySinh = @ngaySinh
            WHERE SDT = @sdt;
			PRINT N'Cập nhật ngày sinh thành công!';
        END

    -- Cập nhật tổng tiền mua sắm nếu không NULL
    IF @tongTienMua IS NOT NULL
        BEGIN
            UPDATE KhachHang
            SET TongTienMua = @tongTienMua
            WHERE SDT = @sdt;
            PRINT N'Cập nhật tổng tiền thành công!';
        END
END;
GO
-- Bo phan quan ly nganh hang
create  proc PhanLoai
@TenLoai nvarchar(50)
as
begin
    BEGIN TRY
    BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
	if not exists(
		select*
		from SanPham
		Where PhanLoai = @TenLoai
	) print(N'Không tồn tại loại sản phẩm này');
	else 
		select*
		from SanPham
		Where PhanLoai = @TenLoai
    COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		-- Nếu có lỗi, SQL Server sẽ nhảy vào đây
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
		END

		-- Thông báo lỗi
		PRINT 'Error occurred!';
		PRINT ERROR_MESSAGE(); -- Lấy thông tin lỗi
	END CATCH
end
go
create proc KiemTraSoLuong
    @ID_SP int,
    @result int output
as
begin
    declare @SLHTK int
    set @SLHTK = (
        select HangTrongKho.SPSPTK
        from HangTrongKho
        where IDSP = @ID_SP)

    if @SLHTK > 0
	begin
        set @result = 1
		print(N'Số lượng hàng trong kho lớn hơn 0')
	end
    else
	begin
        set @result = 0
		print(N'Số lượng hàng trong kho nhỏ hơn hoặc bằng 0')
	end
end
go
create  proc CapNhatTrangThaiSanPhamKhuyenMai
    @ID_SP int
as
begin
	BEGIN TRY
    BEGIN TRANSACTION
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

		if not exists(select*from SanPham where ID = @ID_SP)
		begin
			print(N'Không tồn tại sản phẩm này')
			COMMIT TRANSACTION
			return
		end

        declare @type nvarchar(50), @result int
        exec KiemTraSoLuong @ID_SP, @result output

		if @result = 0
		begin
			update CTCTKMFlashSale
            set KhaDung = 0
            where IDSP = @ID_SP

			update CTCTKMComboSale
            set KhaDung = 0
            where (IDSP1 = @ID_SP or IDSP2 = @ID_SP)

			update CTCTKMMemberSale
            set KhaDung = 0
            where IDSP = @ID_SP

			print concat(N'Cập nhật trạng thái khả dụng của sản phẩm có ID = ',@ID_SP, N' thành không khả dụng')
		end
		else 
		begin
			update CTCTKMFlashSale
            set KhaDung = 1
            where IDSP = @ID_SP

			update CTCTKMComboSale
            set KhaDung = 1
            where (IDSP1 = @ID_SP or IDSP2 = @ID_SP)

			update CTCTKMMemberSale
            set KhaDung = 1
            where IDSP = @ID_SP

			print concat(N'Cập nhật trạng thái khả dụng của sản phẩm có ID = ',@ID_SP, N' thành khả dụng')
		end
    COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		-- Nếu có lỗi, SQL Server sẽ nhảy vào đây
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
		END

		-- Thông báo lỗi
		PRINT 'Error occurred!';
		PRINT ERROR_MESSAGE(); -- Lấy thông tin lỗi
	END CATCH
end
go
create  proc CapNhatTrangThaiKhuyenMai
@ID_CTKM int
as
begin

    BEGIN TRY
    BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED


    declare @NgayBD date, @NgayKT date, @type nvarchar(50)
    select @NgayBD = ThoiGianBatDau, @NgayKT = ThoiGianKetThuc
    from CTKM
    where @ID_CTKM = ID
    if getdate() < @NgayBD or getdate() > @NgayKT
	begin
        update CTKM
        set KhaDung = 0
        where ID = @ID_CTKM
        COMMIT TRANSACTION
		print concat(N'Chương trình khuyến mãi có ID = ', @ID_CTKM,N' thành không khả dụng')

		update CTCTKMFlashSale set KhaDung = 0 where IDCTKM = @ID_CTKM
		update CTCTKMComboSale set KhaDung = 0 where IDCTKM = @ID_CTKM
		update CTCTKMMemberSale set KhaDung = 0 where IDCTKM = @ID_CTKM
        return
	end

    set @type = (
        select LoaiSale
        from CTKM
        where ID = @ID_CTKM
    )

    if @type = 'Flash Sale'
	begin
        if not exists(select*from CTCTKMFlashSale where IDCTKM = @ID_CTKM and KhaDung = 1)
		begin
            update CTKM
            set KhaDung = 0
            where ID = @ID_CTKM
			COMMIT TRANSACTION
			print concat(N'Cập nhật chương trình khuyến mãi có ID = ', @ID_CTKM,N' thành không khả dụng')
			return
		end
	end

    if @type = 'Combo Sale'
	begin
        if not exists(select*from CTCTKMComboSale where IDCTKM = @ID_CTKM and KhaDung = 1)
		begin
			update CTKM
            set KhaDung = 0
            where ID = @ID_CTKM
			COMMIT TRANSACTION
			print concat(N'Cập nhật chương trình khuyến mãi có ID = ', @ID_CTKM,N' thành không khả dụng')
			return
		end
	end
    if @type = 'Member Sale'
	begin
        if not exists(select*from CTCTKMMemberSale where IDCTKM = @ID_CTKM and KhaDung = 1)
		begin
            update CTKM
            set KhaDung = 0
            where ID = @ID_CTKM
			COMMIT TRANSACTION
			print concat(N'Cập nhật chương trình khuyến mãi có ID = ', @ID_CTKM,N' thành không khả dụng')
			return
		end
	end
    update CTKM
    set KhaDung = 1
    where ID = @ID_CTKM
	print concat(N'Cập nhật chương trình khuyến mãi có ID = ', @ID_CTKM,N' thành khả dụng')
    COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		-- Nếu có lỗi, SQL Server sẽ nhảy vào đây
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
		END

		-- Thông báo lỗi
		PRINT 'Error occurred!';
		PRINT ERROR_MESSAGE(); -- Lấy thông tin lỗi
	END CATCH
end
go
create  proc ThemSanPham
    @TenSanPham nvarchar(50),
    @NgaySanXuat date,
    @PhanLoai nvarchar(50),
    @GiaNiemYet float
as
begin
    if not exists(select*from LoaiSanPham where @PhanLoai = Ten) 
	begin
		print(N'Không tồn tại loại sản phẩm này')
		return
	end
    insert into SanPham(TenSP, NgaySanXuat, PhanLoai, GiaNiemYet)
    values(@TenSanPham, @NgaySanXuat, @PhanLoai, @GiaNiemYet)
	print(N'Thêm sản phẩm thành công')
end
go
create  proc XoaSanPham
@ID_SP int
as
begin
    BEGIN TRY
    BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED

	if not exists(select*from SanPham where ID = @ID_SP) 
	begin
		print(N'Không tồn tại sản phẩm này')
		COMMIT TRANSACTION
		return
	end
    delete from SanPham where ID = @ID_SP
	print(N'Xóa sản phẩm thành công')
    COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		-- Nếu có lỗi, SQL Server sẽ nhảy vào đây
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
		END

		-- Thông báo lỗi
		PRINT 'Error occurred!';
		PRINT ERROR_MESSAGE(); -- Lấy thông tin lỗi
	END CATCH
end
go
create  proc CapNhatSanPham
    @ID_SP int,
    @TenSanPham nvarchar(50),
    @NgaySanXuat date,
    @PhanLoai nvarchar(50),
    @GiaNiemYet float
as
begin
    BEGIN TRY
    BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED

	if not exists(select*from SanPham where ID = @ID_SP)
	begin
		print(N'Không tồn tại sản phẩm này')
		COMMIT TRANSACTION
		return
	end

    update SanPham
    set
        TenSP = coalesce(@TenSanPham, TenSP),
        NgaySanXuat = coalesce(@NgaySanXuat, NgaySanXuat),
        PhanLoai = coalesce(@PhanLoai, PhanLoai),
        GiaNiemYet = coalesce(@GiaNiemYet, GiaNiemYet)
    where ID = @ID_SP
	print(N'Cập nhật thành công sản phẩm')
    COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		-- Nếu có lỗi, SQL Server sẽ nhảy vào đây
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
		END

		-- Thông báo lỗi
		PRINT 'Error occurred!';
		PRINT ERROR_MESSAGE(); -- Lấy thông tin lỗi
	END CATCH
end
go
create proc ThemChuongTrinhKhuyenMai
    @TGBatDau date,
    @TGKetThuc date,
    @KhaDung bit,
    @LoaiSale nvarchar(50)
as
begin
    if not exists(select*from CTKM where LoaiSale = @LoaiSale)
	begin
		print(N'Không tồn tại loại khuyến mãi này')
		return
	end
    insert into CTKM(ThoiGianBatDau, ThoiGianKetThuc, KhaDung, LoaiSale)
    values(@TGBatDau, @TGKetThuc, @KhaDung, @LoaiSale)
	print(N'Thêm chương trình khuyến mãi thành công')
end
go
create proc XoaChuongTrinhKhuyenMai
@ID_CTKM int
as
begin
    delete from CTKM where ID = @ID_CTKM
    delete from CTCTKMFlashSale where IDCTKM = @ID_CTKM
    delete from CTCTKMComboSale where IDCTKM = @ID_CTKM
    delete from CTCTKMMemberSale where IDCTKM = @ID_CTKM
end
go
create proc CapNhatChuongTrinhKhuyenMai
    @ID int,
    @TGBatDau date,
    @TGKetThuc date,
    @KhaDung bit,
    @LoaiSale nvarchar(50)
as
begin
    update CTKM
    set
        ThoiGianBatDau = coalesce(@TGBatDau, ThoiGianBatDau),
        ThoiGianKetThuc = coalesce(@TGKetThuc, ThoiGianKetThuc),
        KhaDung = coalesce(@KhaDung, KhaDung),
        LoaiSale = coalesce(@LoaiSale, LoaiSale)
    where ID = @ID
end
go
create proc ThemCTCTKM_FlashSale
    @IDCTKM int,
    @ID_SP int,
    @SL_KM int,
    @PhanTramKM int
as
begin
    if not exists(select*from CTCTKMFlashSale where IDCTKM = @IDCTKM)
        begin
            declare @SLHTK int
            set @SLHTK = (
                select HangTrongKho.SPSPTK
                from HangTrongKho
                where IDSP = @ID_SP
            )
            if @SL_KM > @SLHTK
                raiserror(N'Số lượng khuyến mãi lớn hơn số lượng hàng trong kho', 16, 1);
            else
                insert into CTCTKMFlashSale(IDSP, IDCTKM, SLKM, PhanTramKM, KhaDung)
                values(@ID_SP, @IDCTKM, @SL_KM, @PhanTramKM, 1)
        end
end
go
create proc ThemCTCTKM_ComboSale
    @IDCTKM int,
    @ID_SP1 int,
    @ID_SP2 int,
    @SL_KM int,
    @PhanTramKM int
as
begin
    if not exists(select*from CTCTKMComboSale where IDCTKM = @IDCTKM)
        begin
            declare @SLHTK1 int, @SLHTK2 int
            set @SLHTK1 = (
                select HangTrongKho.SPSPTK
                from HangTrongKho
                where IDSP = @ID_SP1
            )
            set @SLHTK2 = (
                select HangTrongKho.SPSPTK
                from HangTrongKho
                where IDSP = @ID_SP2
            )
            if @SL_KM > @SLHTK1 or @SL_KM > @SLHTK2
                raiserror(N'Số lượng khuyến mãi lớn hơn số lượng hàng trong kho', 16, 1);
            else
                insert into CTCTKMComboSale(IDSP1, IDSP2, IDCTKM, SLKM, PhanTramKM, KhaDung)
                values(@ID_SP1, @ID_SP2, @IDCTKM, @SL_KM, @PhanTramKM, 1)
        end
end
go
create proc ThemCTCTKM_MemberSale
    @IDCTKM int,
    @ID_SP int,
    @SL_KM int
as
begin
    if not exists(select*from CTCTKMMemberSale where IDCTKM = @IDCTKM)
        begin
            declare @SLHTK int
            set @SLHTK = (
                select HangTrongKho.SPSPTK
                from HangTrongKho
                where IDSP = @ID_SP
            )
            if @SL_KM > @SLHTK
                raiserror(N'Số lượng khuyến mãi lớn hơn số lượng hàng trong kho', 16, 1);
            else
                begin
                    insert into CTCTKMMemberSale(IDSP, IDCTKM, SLKM, KhaDung)
                    values(@ID_SP, @IDCTKM, @SL_KM, 1)

                    declare LoaiKHCursor cursor for
                        select ten from LoaiKhachHang

                    declare @LoaiKhachHang nvarchar(50)

                    open LoaiKHCursor
                    fetch next from LoaiKHCursor into @LoaiKhachHang

                    while @@FETCH_STATUS = 0
                        begin
                            insert into CTUuDaiMemberSale(IDCTKM, IDSP, LoaiKhachHang)
                            values(@IDCTKM, @ID_SP, @LoaiKhachHang)
                            fetch next from LoaiKHCursor into @LoaiKhachHang
                        end
                    close LoaiKHCursor
                    deallocate LoaiKHCursor
                end
        end
end
go
create proc XoaCTCTKM_FlashSale
    @ID_CTKM int,
    @ID_SP int
as
begin
    delete from CTCTKMFlashSale where IDCTKM = @ID_CTKM and IDSP = @ID_SP
end
go
create proc XoaCTCTKM_ComboSale
    @ID_CTKM int,
    @ID_SP1 int,
    @ID_SP2 int
as
begin
    delete from CTCTKMComboSale where IDCTKM = @ID_CTKM and IDSP1 = @ID_SP1 and IDSP2 = @ID_SP2
end
go
create proc XoaCTCTKM_MemberSale
    @ID_CTKM int,
    @ID_SP int
as
begin
    delete from CTCTKMMemberSale where IDCTKM = @ID_CTKM and IDSP = @ID_SP
    delete from CTUuDaiMemberSale where IDCTKM = @ID_CTKM and IDSP = @ID_SP
end
go
create  proc ThemPhanTramKM_MemberSale
    @ID_CTKM int,
    @ID_SP int,
    @LoaiKhachHang nvarchar(50),
    @PhanTramKM int
as
begin
    update CTUuDaiMemberSale
    set PhanTramKM = @PhanTramKM
    where IDCTKM = @ID_CTKM and IDSP = @ID_SP and LoaiKhachHang = @LoaiKhachHang
end
go
-- Bo phan xu ly don hang
CREATE PROCEDURE TinhTongTien
    @sdt nvarchar(25),
    @id_dh INT,
    @TongTienDH INT OUTPUT,
    @TongGiamGia INT OUTPUT
AS
BEGIN
    -- Initialize output variables
    SET @TongTienDH = 0;
    SET @TongGiamGia = 0;
	BEGIN try
    BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ

    DECLARE product_cursor CURSOR LOCAL
        FOR
        SELECT IDSP, SL
        FROM CTDH
        WHERE IDDH = @id_dh;

    DECLARE @ID_SP INT,
        @SoLuong INT,
        @GiaNiemYet FLOAT,
        @TienSP FLOAT;

    OPEN product_cursor;

    FETCH NEXT FROM product_cursor INTO @ID_SP, @SoLuong;

    WHILE @@FETCH_STATUS = 0
        BEGIN
			IF @SoLuong > (SELECT SPSPTK FROM HangTrongKho WHERE IDSP = @ID_SP)
			BEGIN
				THROW 50001, 'Số lượng sản phẩm không đủ trong kho', 1;
			END

            SELECT @GiaNiemYet = GiaNiemYet
            FROM SanPham
            WHERE ID = @ID_SP;

            -- Step 2.2: Calculate product cost and add to total
            SET @TienSP = @SoLuong * @GiaNiemYet;
			UPDATE CTDH SET Gia = @TienSP WHERE IDSP = @ID_SP
            SET @TongTienDH = @TongTienDH + @TienSP;

            UPDATE HangTrongKho
            SET SPSPTK -= @SoLuong
            WHERE IDSP = @ID_SP;

            FETCH NEXT FROM product_cursor INTO @ID_SP, @SoLuong;
        END

    CLOSE product_cursor;
    DEALLOCATE product_cursor;

    EXEC ApDungKhuyenMai @sdt, @id_dh, @TongGiamGia OUTPUT;
    DECLARE @VoucherDiscount FLOAT = 0;
    EXEC ApDungVoucher @sdt, @VoucherDiscount OUTPUT;

    SET @TongGiamGia = @TongGiamGia + @VoucherDiscount;
    -- Step 6: Update order details
    UPDATE DonHang
    SET TongTien = @TongTienDH,
        TongGiamGia = @TongGiamGia,
        TrangThai = N'Đã thanh toán'
    WHERE ID = @id_dh;
    UPDATE KhachHang
    SET TongTienMua +=(@TongTienDH - @TongGiamGia)
    WHERE SDT = @sdt;
	print 'Tong Tien DH:' + convert(varchar(20), @TongTienDH);
	print 'Tong Giam Gia:' + convert(varchar(20), @TongGiamGia);

    COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
	BEGIN
        ROLLBACK TRANSACTION;
		THROW
	END
	END CATCH
END
GO
CREATE TYPE DSCTDH AS TABLE(
	IDSP INT,
	SL INT
)
GO
CREATE PROCEDURE TaoDonHang
    @sdt VARCHAR(25),
	@ct_dh DSCTDH READONLY
 
AS
BEGIN
    BEGIN TRANSACTION
	SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    BEGIN TRY
        DECLARE @id_dh INT;

        INSERT INTO DonHang
        (NgayMua,TrangThai, IDKH)
        VALUES
            (GETDATE(), N'Chưa thanh toán', @sdt);

        -- Lấy ra ID của Đơn Hàng vừa tạo
        SET @id_dh = SCOPE_IDENTITY();

        -- Khai báo con trỏ để duyệt qua các chi tiết đơn hàng trong @ct_dh
        DECLARE @id_sp INT, @so_luong INT;

        DECLARE ct_dh_cursor CURSOR LOCAL FOR
            SELECT IDSP, SL
            FROM @ct_dh;

        OPEN ct_dh_cursor;

        FETCH NEXT FROM ct_dh_cursor INTO @id_sp, @so_luong;

        WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO CTDH (IDSP, IDDH, SL, Gia)
                VALUES (@id_sp, @id_dh, @so_luong, 0);

                FETCH NEXT FROM ct_dh_cursor INTO @id_sp, @so_luong;
            END;

        CLOSE ct_dh_cursor;
        DEALLOCATE ct_dh_cursor;
		print 'Tao thanh cong don hang voi ID:' + Convert(NVARCHAR(50), @id_dh);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
CREATE PROCEDURE ApDungKhuyenMai
    @sdt nvarchar(25),
    @id_dh INT,
    @TongTienGiamGia INT OUTPUT
AS
BEGIN
    SET @TongTienGiamGia = 0;
    -- Áp dụng flash sale
    DECLARE flash_sale_cursor CURSOR LOCAL FOR
	SELECT IDSP, SL
	FROM CTDH
	WHERE IDDH = @id_dh
	FOR UPDATE;
	DECLARE @ID_SP INT;
	DECLARE @SL INT;
	DECLARE @SoTienGiam INT;
	Declare @Gia_niem_Yet INT;

    OPEN flash_sale_cursor;

    FETCH NEXT FROM flash_sale_cursor INTO @ID_SP, @SL;
		
    WHILE @@FETCH_STATUS = 0
	BEGIN
        select @Gia_niem_Yet = GiaNiemYet
        FROM SanPham
        where ID = @ID_SP

        EXEC FlashSale @ID_SP,@id_dh,@SL, @Gia_niem_Yet, @SoTienGiam OUTPUT;

        SET @TongTienGiamGia = @TongTienGiamGia + @SoTienGiam;
        FETCH NEXT FROM flash_sale_cursor INTO @ID_SP, @SL; -- Thêm ở đây, fetch next thiếu @SL
    END

	print 'Tong Giam Gia sau flashsales:' + convert(varchar(20), @TongTienGiamGia);
    CLOSE flash_sale_cursor;
    DEALLOCATE flash_sale_cursor;

    -- Áp dụng combo-sale
    DECLARE combo_sale_cursor CURSOR LOCAL FOR
        SELECT IDSP, SL
        FROM CTDH
        WHERE IDDH = @id_dh and IDCTKM IS NULL
        FOR
            UPDATE;

    OPEN combo_sale_cursor;

    FETCH NEXT FROM combo_sale_cursor INTO @ID_SP, @SL;
		
    WHILE @@FETCH_STATUS = 0
    BEGIN
       select @Gia_niem_Yet = GiaNiemYet
        FROM Sanpham
        where ID = @ID_SP

        EXEC ComboSale @ID_SP, @id_dh, @SL, @Gia_niem_Yet, @SoTienGiam OUTPUT;
		print'tong tien giam:' + convert(nvarchar(20),@SoTienGiam)

        SET @TongTienGiamGia = @TongTienGiamGia + @SoTienGiam;
        FETCH NEXT FROM combo_sale_cursor INTO @ID_SP, @SL;
    END
	print 'Tong Giam Gia sau combo sales:' + convert(varchar(20), @TongTienGiamGia);

    CLOSE combo_sale_cursor;
    DEALLOCATE combo_sale_cursor;

    -- Kiểm tra khách hàng thân thiết
    DECLARE @CheckKHTT BIT;
    EXEC KiemTraKHTT @sdt, @CheckKHTT OUTPUT;

    IF @CheckKHTT = 1
    BEGIN
    -- Áp dụng member-sale
    DECLARE member_sale_cursor CURSOR LOCAL FOR
        SELECT IDSP, SL
        FROM CTDH
        WHERE IDDH = @id_dh and IDCTKM IS NULL
        FOR
            UPDATE;

    OPEN member_sale_cursor;

   FETCH NEXT FROM member_sale_cursor INTO @ID_SP, @SL;
    WHILE @@FETCH_STATUS = 0
	BEGIN
        select @Gia_niem_Yet = GiaNiemYet
        FROM Sanpham
        where ID = @ID_SP
        EXEC MemberSale @ID_SP,@id_dh, @SL, @Gia_niem_Yet, @SDT, @SoTienGiam OUTPUT;
        SET @TongTienGiamGia = @TongTienGiamGia + @SoTienGiam;

        FETCH NEXT FROM member_sale_cursor INTO @ID_SP, @SL;
    END
	print 'Tong Giam Gia Sau MemberSale:' + convert(varchar(20), @TongTienGiamGia);
    CLOSE member_sale_cursor;
    DEALLOCATE member_sale_cursor;
    END
END
GO
CREATE PROCEDURE FlashSale
    @id_sp INT,
	@id_dh int,
    @sl INT,
    @gia FLOAT,
    @TongGiamGia INT OUTPUT
AS
BEGIN
    SET @TongGiamGia = 0;
    DECLARE @id_ctkm INT, @phan_tram_giam FLOAT;
    SET @TongGiamGia = 0;

    -- Kiểm tra sản phẩm có trong CTKM Flash Sale
    SELECT @id_ctkm = IDCTKM, @phan_tram_giam = PhanTramKM
    FROM CTCTKMFlashSale
    WHERE IDSP = @id_sp AND SLKM > 0 AND KhaDung = 1;

    IF @id_ctkm IS NOT NULL
        BEGIN
			print 'SP: ' + convert(nvarchar(20),@id_sp) + ' - SL: ' +  convert(nvarchar(20),@sl)

            -- Tính số lượng áp dụng khuyến mãi (tối đa là 3 sản phẩm)
			DECLARE @so_luong_ap_dung INT
            Set @so_luong_ap_dung = CASE WHEN @sl > 3 THEN 3 ELSE @sl END;
            -- Tính tiền giảm giá

			print'Ap dung Flash-Sale cho san pham, so luong ap dung: ' + convert(nvarchar(20), @so_luong_ap_dung)
			print convert(nvarchar(20), @sl)
            SET @TongGiamGia += @so_luong_ap_dung * @gia * @phan_tram_giam / 100;

            -- Cập nhật ID-CTKM cho sản phẩm trong CT-DH
            UPDATE CTDH SET IDCTKM = @id_ctkm WHERE IDSP = @id_sp AND IDDH = @id_dh;
			UPDATE CTDH SET Gia = Gia - @TongGiamGia where IDSP = @id_sp AND IDDH = @id_dh;
            -- Cập nhật số lượng khuyến mãi
            UPDATE CTCTKMFlashSale
            SET SLKM -= @so_luong_ap_dung
            WHERE IDSP = @id_sp;
            -- Cập nhật trạng thái khuyến mãi của sản phẩm
            exec CapNhatTrangThaiSanPhamKhuyenMai @id_sp
        END
END
GO
CREATE PROCEDURE ComboSale
    @ID_SP INT,
	@ID_DH INT,
    @SL INT,
    @Gia FLOAT,
    @TongGiamGia INT OUTPUT
AS
BEGIN
    SET @TongGiamGia = 0;
    DECLARE @GiaSanPhamKetHop FLOAT;
    DECLARE @SoLuongApDung INT;
    DECLARE @SanPhamKetHop INT;
    DECLARE @SL_SPKetHop INT;

    -- 1. Khai báo cursor lấy các combo-sale có ID-SP trong bảng CTCTKM-ComboSale
    DECLARE @IDSanPham1 INT;
    DECLARE @IdSanPham2 INT;
    DECLARE @ID_CTKM INT;
    DECLARE @PhanTramGiam FLOAT;
    DECLARE @KhaDung BIT;

    DECLARE ComboSaleCursor CURSOR LOCAL FOR
        SELECT IDSP1, IDSP2, IDCTKM, PhanTramKM, KhaDung
        FROM CTCTKMComboSale
        WHERE IDSP1 = @ID_SP OR IDSP2 = @ID_SP AND SLKM > 0;

    OPEN ComboSaleCursor;

    FETCH NEXT FROM ComboSaleCursor INTO @IDSanPham1, @IDSanPham2, @ID_CTKM, @PhanTramGiam, @KhaDung;

    WHILE @@FETCH_STATUS = 0
        BEGIN

            -- 1.1.1 Kiểm tra sản phẩm kết hợp và lấy giá sản phẩm kết hợp
            set @GiaSanPhamKetHop = 0;
            SET @SanPhamKetHop = NULL;
            SET @SL_SPKetHop = 0;

            IF (@ID_SP = @IDSanPham1 AND @KhaDung = 1)
                BEGIN
                    -- Kiểm tra sản phẩm kết hợp
                    IF EXISTS (SELECT 1
                               FROM CTDH
                               WHERE IDSP = @IDSanPham2 AND IDDH = @ID_DH)
                        BEGIN
                            SET @SanPhamKetHop = @IDSanPham2;
                            SELECT @SL_SPKetHop = SL
                            FROM CTDH
                            WHERE IDSP = @IDSanPham2;
                        END
                END
            ELSE IF (@ID_SP = @IDSanPham2 AND @KhaDung = 1)
                BEGIN
                    -- Kiểm tra sản phẩm kết hợp
                    IF EXISTS (SELECT 1
                               FROM CTDH
                               WHERE IDSP = @IDSanPham1 AND IDDH = @ID_DH)
                        BEGIN
                            SET @SanPhamKetHop = @IDSanPham1;
                            SELECT @SL_SPKetHop = SL
                            FROM CTDH
                            WHERE IDSP = @IDSanPham1;
                        END
                END

            IF @SanPhamKetHop IS NOT NULL
                BEGIN
					print 'Tim thay Combo-sale trong gio hang ' + convert(nvarchar(20),@id_sp) + '-' + convert(nvarchar(20), @SanPhamKetHop)
					print 'SP:' + convert(nvarchar(20),@id_sp) + '- SL:' + convert(nvarchar(20),@sl) 
					print 'SP2:' + convert(nvarchar(20),@SanPhamKetHop) + '- SL:' + convert(nvarchar(20),@SL_SPKetHop) 

                    -- Lấy giá sản phẩm kết hợp
                    SELECT @GiaSanPhamKetHop = GiaNiemYet
                    FROM SanPham
                    WHERE ID = @SanPhamKetHop;

                    -- 2. Tính toán số lượng tối đa áp dụng giảm giá
                    SET @SoLuongApDung = CASE 
					WHEN @SL > @SL_SPKetHop THEN 
						CASE 
							WHEN @SL_SPKetHop > 3 THEN 3
							ELSE @SL_SPKetHop
						END
					ELSE 
						CASE 
							WHEN @SL > 3 THEN 3
							ELSE @SL
						END
					END

					print'Ap dung combo-sale cho cap san pham, so luong ap dung: ' + convert(nvarchar(20), @SoLuongApDung)
                    SET @TongGiamGia += @SoLuongApDung * (@Gia + @GiaSanPhamKetHop) * (@PhanTramGiam / 100);
					-- Cập nhật giá lại
					UPDATE CTDH SET Gia = Gia - (@SoLuongApDung*Gia*(@PhanTramGiam / 100.0)) where IDSP = @id_sp AND IDDH = @ID_DH
					UPDATE CTDH SET Gia = Gia - (@SoLuongApDung*@GiaSanPhamKetHop*(@PhanTramGiam / 100)) where IDSP = @SanPhamKetHop AND IDDH = @ID_DH
                    -- 3. Cập nhật ID_CTKM cho sản phẩm
                    UPDATE CTDH SET IDCTKM = @ID_CTKM WHERE IDSP = @ID_SP AND IDDH = @ID_DH;
                    UPDATE CTDH SET IDCTKM = @ID_CTKM WHERE IDSP = @SanPhamKetHop AND IDDH = @ID_DH;

                    -- 4. Cập nhật SL_KM
                    UPDATE CTCTKMComboSale
                    SET SLKM = SLKM - @SoLuongApDung
                    WHERE IDCTKM = @ID_CTKM;

                    -- 5. Gọi procedure cập nhật trạng thái
                    EXEC CapNhatTrangThaiSanPhamKhuyenMai @ID_SP;
                    EXEC CapNhatTrangThaiSanPhamKhuyenMai @SanPhamKetHop;
                    -- Kết thúc khi đã xử lý thành công
					BREAK;
                END
            FETCH NEXT FROM ComboSaleCursor INTO @IDSanPham1, @IDSanPham2, @ID_CTKM, @PhanTramGiam, @KhaDung;
        END

    CLOSE ComboSaleCursor;
    DEALLOCATE ComboSaleCursor;
    RETURN;
END
GO
CREATE PROCEDURE MemberSale
    @id_sp INT,
	@id_dh INT,
    @sl INT,
    @gia FLOAT,
    @sdt varchar(25),
    @TongGiamGia INT OUTPUT
AS
BEGIN
    DECLARE @LoaiKhachHang NVARCHAR(50);
    DECLARE @ID_CTKM INT;
    DECLARE @PhanTramGiam FLOAT;
    DECLARE @SLApDung INT;
    SET @TongGiamGia = 0

    -- 1. Kiểm tra nếu @id_sp tồn tại trong bảng CTCTKM_MemberSale và khả dụng
        IF EXISTS (
            SELECT 1
            FROM CTCTKMMemberSale
            WHERE IDSP = @id_sp AND KhaDung = 1 AND SLKM > 0
            )
            BEGIN
				print 'SP: ' + convert(nvarchar(20),@id_sp) + ' - SL: ' +  convert(nvarchar(20),@sl)
                -- 2. Lấy Loại-Khách-Hàng từ bảng KhachHang dựa trên @sdt
                SELECT @LoaiKhachHang = LoaiKH
                FROM KhachHang
                WHERE SDT = @sdt;

                -- 3. Lấy ID_CTKM và phần trăm khuyến mãi từ bảng CT_UuDai_MemberSale
                SELECT @ID_CTKM = IDCTKM, @PhanTramGiam = PhanTramKM
                FROM CTUuDaiMemberSale
                WHERE IDSP = @id_sp AND LoaiKhachHang = @LoaiKhachHang;

                -- 4. Tính toán số lượng tối đa được giảm
                SET @SLApDung = CASE
                                    WHEN @sl > 3 THEN 3
                                    ELSE @sl
                    END;
				print'Ap dung member-Sale cho san pham, so luong ap dung: ' + convert(nvarchar(20), @SLApDung)
                SET @TongGiamGia = @SLApDung * @gia * (@PhanTramGiam / 100.0);

                -- 5. Cập nhật ID_CTKM của sản phẩm trong bảng CT_DH
                UPDATE CTDH
                SET IDCTKM = @ID_CTKM
                WHERE IDSP = @id_sp AND IDDH = @ID_DH;

				UPDATE CTDH
				SET Gia = Gia - @TongGiamGia
				WHERE IDSP = @id_sp AND @id_dh = IDDH;

                -- 6. Cập nhật SL_KM của CTCTKM_MemberSale
                UPDATE CTCTKMMemberSale
                SET SLKM = SLKM - @SLApDung
                WHERE IDSP = @id_sp AND KhaDung = 1;

                -- 7. Gọi procedure CapNhatTrangThaiSanPhamKhuyenMai
                EXEC CapNhatTrangThaiSanPhamKhuyenMai @id_sp;

				print'Ap dung member-sale cho san pham ' + convert(nvarchar(20),@id_sp)
            END
END
GO
CREATE PROCEDURE ApDungVoucher
    @sdt varchar(25),
    @TongTien FLOAT OUTPUT
AS
BEGIN
    SET @TongTien = 0;
    -- Kiểm tra xem khách hàng có tồn tại trong bảng KhachHang và voucher có bằng True hay không
    IF @sdt IS NOT NULL AND EXISTS (SELECT 1
               FROM KhachHang
               WHERE sdt = @sdt AND voucher = 1)
        BEGIN
            DECLARE @LoaiKH NVARCHAR(50);
            SELECT @LoaiKH = LoaiKH
            FROM KhachHang
            WHERE SDT = @sdt;

            SELECT @TongTien = UuDai
            FROM LoaiKhachHang
            WHERE Ten = @LoaiKH;
            exec ThayDoiVoucher @sdt, 0;
        END
END;
GO
CREATE PROCEDURE KiemTraKHTT
    @sdt VARCHAR(25),
    @khtt INT OUTPUT
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM KhachHang
               WHERE sdt = @sdt)
        BEGIN
            SET @khtt = 1;
        END
    ELSE
        BEGIN
            SET @khtt = 0;
        END
END;
GO
-- Bộ phận kinh doanh
CREATE PROCEDURE ThongKeChung (
    @ngayTK DATETIME,
    @DT FLOAT OUTPUT,
    @SLKH INT OUTPUT
)
AS
BEGIN

    SET @DT = 0;
    SET @SLKH = 0;

    -- Kiểm tra @ngayTK không được vượt quá ngày hiện tại.
    IF @ngayTK > GETDATE()
        BEGIN
            PRINT N'Lỗi: Ngày thống kê không được vượt quá ngày hiện tại.';
            RETURN;
        END

    BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    BEGIN TRY
        -- 1. tính tổng doanh thu và số lượng khách hàng
        SELECT
             @DT = ISNULL(SUM(TongTien), 0), -- Gán giá trị 0 nếu NULL
			@SLKH = ISNULL(COUNT(DISTINCT IDKH), 0) -- Gán giá trị 0 nếu NULL
        FROM DonHang
        WHERE NgayMua = @ngayTK;

        -- 2. kiểm tra @ngayTK đã tồn tại trong bảng Thong-Ke hay chưa
        IF EXISTS (SELECT 1 FROM ThongKe WHERE NgayThongKe = @ngayTK)
            BEGIN
                UPDATE ThongKe
                SET
                    TongDoanhThu = @DT,
					TongSLKH = @SLKH
            WHERE NgayThongKe = @ngayTK;
            END
        ELSE
            BEGIN
                INSERT INTO ThongKe (NgayThongKe, TongDoanhThu, TongSLKH)
                VALUES (@ngayTK, @DT, @SLKH);
            END;

        COMMIT TRANSACTION;

        PRINT N'Thống kê hoàn tất.';
        PRINT N'Tổng doanh thu: ' + FORMAT(@DT, 'N2');
        PRINT N'Tổng số lượng khách hàng: ' + CAST(@SLKH AS VARCHAR);
    END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
			PRINT 'Rollback transaction.';
		END
        PRINT N'Lỗi xảy ra: ' + ERROR_MESSAGE();
    END CATCH;
END;
GO


CREATE PROCEDURE ThongKeTuyChon (
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
				-- Xác định ngày đầu tuần và ngày cuối tuần
				DECLARE @ngayDauTuan DATE, @ngayCuoiTuan DATE;

				-- Tính ngày đầu tuần (Thứ Hai)
				SET @ngayDauTuan = DATEADD(DAY, -((DATEPART(WEEKDAY, @ngayBatDau) + 5) % 7), @ngayBatDau);

				-- Tính ngày cuối tuần (Chủ Nhật)
				SET @ngayCuoiTuan = DATEADD(DAY, 6, @ngayDauTuan);

				-- Thống kê tổng doanh thu và số lượng khách hàng
				SELECT
					@DT = ISNULL(SUM(TongTien), 0),
					@SLKH = ISNULL(COUNT(DISTINCT IDKH), 0)
				FROM DonHang
				WHERE CONVERT(DATE, NgayMua) BETWEEN @ngayDauTuan AND @ngayCuoiTuan;

				PRINT N'Ngày đầu tuần: ' + CAST(@ngayDauTuan AS NVARCHAR);
				PRINT N'Ngày cuối tuần: ' + CAST(@ngayCuoiTuan AS NVARCHAR);
			END
        ELSE IF @kieuThongKe = 'THANG'
            BEGIN
                SELECT
                    @DT = ISNULL(SUM(TongTien),0),
                    @SLKH = ISNULL(COUNT(DISTINCT IDKH), 0)
                FROM DonHang
                WHERE MONTH(NgayMua) = MONTH(@ngayBatDau) AND YEAR(NgayMua) = YEAR(@ngayBatDau); -- Tính tháng
            END
        ELSE IF @kieuThongKe = 'KHOANG'
            BEGIN
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
        IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
			PRINT 'Rollback transaction.';
		END
        PRINT N'Lỗi xảy ra: ' + ERROR_MESSAGE();
    END CATCH;
END;
GO


CREATE PROCEDURE ThongKeSanPham (
    @ngayTK DATETIME         -- ngay thong ke
)
AS
BEGIN
    IF @ngayTK > GETDATE()
        BEGIN
            PRINT N'Lỗi: Ngày thống kê không được vượt quá ngày hiện tại.';
            RETURN;
        END

    BEGIN TRANSACTION;

    -- Thiết lập mức cách ly READ UNCOMMITTED
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    BEGIN TRY

        DECLARE @maSP INT;
        DECLARE @So_Luong_Da_Ban INT = 0;
        DECLARE @SLKH_Dat_Mua INT = 0;

        -- Con trỏ để duyệt qua id sản phẩm
        DECLARE ProductCursor CURSOR LOCAL DYNAMIC FORWARD_ONLY READ_ONLY
            FOR SELECT ID FROM SanPham;

        -- Mở con trỏ
        OPEN ProductCursor;

        -- Đọc từng sản phẩm từ con trỏ
        FETCH NEXT FROM ProductCursor INTO @maSP;

        WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @So_Luong_Da_Ban = 0;
                SET @SLKH_Dat_Mua = 0;

                -- 2.1. Tính tổng số lượng đã bán cho sản phẩm có @maSP
                SELECT
                    @So_Luong_Da_Ban = ISNULL(SUM(SL), 0)
                FROM CTDH CT
                WHERE CT.IDSP = @maSP
                  AND CT.IDDH IN (
                    SELECT ID
                    FROM DonHang
                    WHERE NgayMua = @ngayTK
                );

                -- 2.2. Tính số lượng khách hàng đã đặt mua sản phẩm @maSP

                SELECT
                    @SLKH_Dat_Mua = ISNULL(COUNT(DISTINCT DH.IDKH), 0)
                FROM CTDH CT JOIN DonHang DH ON DH.ID = CT.IDDH
                WHERE CT.IDSP = @maSP
                  AND CT.IDDH IN (
                    SELECT ID
                    FROM DonHang
                    WHERE NgayMua = @ngayTK
                );

                -- 3. Kiểm tra nếu ngày thống kê và sản phẩm đã tồn tại
                IF EXISTS (
                    SELECT 1 FROM ThongKeSP
                    WHERE NgayThongKe = @ngayTK AND IDSP = @maSP
                )
                    BEGIN
                        UPDATE ThongKeSP
                        SET SLDaBan = @So_Luong_Da_Ban,
                            SLKHDatMua = @SLKH_Dat_Mua
                WHERE NgayThongKe = @ngayTK AND IDSP = @maSP;
                    END
                ELSE
                    BEGIN
                        INSERT INTO ThongKeSP(NgayThongKe, IDSP, SLDaBan, SLKHDatMua)
                        VALUES (@ngayTK, @maSP, @So_Luong_Da_Ban, @SLKH_Dat_Mua);
                    END;

                FETCH NEXT FROM ProductCursor INTO @maSP;
            END;

        CLOSE ProductCursor;
        DEALLOCATE ProductCursor;

        SELECT *
        FROM ThongKeSP
		WHERE NgayThongKe = @ngayTK
        ORDER BY SLDaBan DESC;

        COMMIT TRANSACTION;
    END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
			PRINT 'Rollback transaction.';
		END
        PRINT N'Lỗi xảy ra: ' + ERROR_MESSAGE();
    END CATCH;
END;
GO