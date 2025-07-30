-- ############################################## Bộ phận chăm sóc khách hàng ######################################
-- #################################################################################################################
-- #################################################################################################################
    -- Proc PhanHangKH
        -- in ra cac kh phan hang sai
        select kh.SDT as DScacKHcanPhanHang, kh.NgaySinh, kh.NgayDangKy, kh.LoaiKH, kh.TongTienMua, kh.Voucher
        from KhachHang kh 
        where kh.LoaiKH != (
            SELECT top 1 Ten
            FROM LoaiKhachHang
            WHERE kh.TongTienMua >= NguongTren
            ORDER BY NguongTren DESC
        )
        -- chay proc phanhang
        exec PhanHangKH
        -- sau khi phan hang => dang sach ban dau rong 
        select kh.SDT as DScacKHcanPhanHang, kh.NgaySinh, kh.NgayDangKy, kh.LoaiKH, kh.TongTienMua, kh.Voucher
        from KhachHang kh 
        where kh.LoaiKH != (
            SELECT top 1 Ten
            FROM LoaiKhachHang
            WHERE kh.TongTienMua >= NguongTren
            ORDER BY NguongTren DESC
        )
    -- Proc ThongBaoPhieuMH
        -- danh sach khach hang co thang sinh trung thang hien tai
        select kh.SDT as DScacKHcanThongbao, kh.NgaySinh, kh.NgayDangKy, kh.LoaiKH, kh.TongTienMua, kh.Voucher
        from KhachHang kh
        where Month(NgaySinh) = MONTH(getdate())
        --chay proc ThongBaoPhieuMh
        exec ThongBaoPhieuMH
        -- trang thai voucher da duoc cap nhat
        select kh.SDT as DScacKHcanThongbao, kh.NgaySinh, kh.NgayDangKy, kh.LoaiKH, kh.TongTienMua, kh.Voucher
        from KhachHang kh
        where Month(NgaySinh) = MONTH(getdate())    
    -- Proc them khach hang
        exec TaoTKKH '0987654341','08/08/2000'
    -- Proc Cap nhat thong tin khach hang
        exec CapNhatThongTinKhachHang '0987654341','09/08/2000',1
    -- Proc Xoa TK khach hang
        exec XoaTKKH '0987654341'
    -- Kiem tra danh sach khach hang
        select * from KhachHang 

-- ############################################# Bộ phận QLNH ######################################################
-- #################################################################################################################
-- #################################################################################################################
    --Phân loại sản phẩm
    	--TH1: Tồn tại sản phẩm thuộc loại đó
    	exec PhanLoai 'Máy in'
    
    	--TH2: Không tồn tại loại sản phẩm đó
    	exec PhanLoai 'Máy photocopy'
    --Cập nhật trạng thái khuyến mãi
	
	    --TH1: Khuyến mãi đó có ngày khuyến mãi nằm ngoài ngày hiện tại
	    update CTKM set KhaDung = 1 where ID = 2
	    select*from CTKM where ID = 2
	    exec CapNhatTrangThaiKhuyenMai 2
        
	    select*from CTCTKMFlashSale where IDCTKM = 2
	    select*from CTCTKMComboSale where IDCTKM = 2
	    select*from CTCTKMMemberSale where IDCTKM = 2
    
    --Thêm chương trình khuyến mãi
	    --TH1: Không tồn tại loại khuyến mãi này
	    exec ThemChuongTrinhKhuyenMai '2024-01-11', '2024-01-20', 1, 'null'

	    --TH2: Thêm thành công
	    exec ThemChuongTrinhKhuyenMai '2024-01-11', '2024-01-20', 1, 'Flash Sale'  
        select * from CTKM
		DECLARE @IDCTKM INT
		SET @IDCTKM = SCOPE_IDENTITY();
	    exec ThemCTCTKM_FlashSale 37, 1, 40, 15
	    select*from CTCTKMFlashSale where IDCTKM = 37


-- ############################################# Bộ phận XLĐH ######################################################
-- #################################################################################################################
-- #################################################################################################################
    -- TaoDonHang
        declare @ct_dh DSCTDH;
        insert into @ct_dh(IDSP,SL) 
        values (1,1),
            (2,1),
            (11,1),
            (12,1),
            (18,1)
        exec TaoDonHang '0987654324',@ct_dh

    -- TinhTongTien 
        DECLARE @TongTienDH int, @TongGiamGia int
        exec TinhTongTien '0987654324', 20, @TongTienDH, @TongGiamGia

-- ############################################# Bộ phận QLKH ######################################################
-- #################################################################################################################
-- #################################################################################################################
    -- Proc KiemTraKho
        -- Kiểm tra trước khi kiểm tra kho
            select id as DDHTruocKhiKiemTraKho , * from DonDatHang;
        -- Chạy proc
            exec KiemTraKho;
        -- Kiểm tra sau khi kiểm tra kho
            select id as DDHSauKhiKiemTraKho,  * from DonDatHang;
    -- Proc ThemDonGiaoHang
        -- Kiểm tra trước khi thêm đơn giao hàng
            select id as DDHTruocKhiKiemTraKho , * from DonDatHang;
            select IDSP as HTKTruocKhiThemDGH, * from HangTrongKho;
        -- Chạy proc
            declare @ds_ctdgh DSCTDGH;
            INSERT @ds_ctdgh (IDDDH, SL) VALUES(68, 85), (69,95);
            exec ThemDonGiaoHang @ds_ctdgh;
        -- Kiểm tra trước khi thêm đơn giao hàng
            select id as DDHSauKhiKiemTraKho, * from DonDatHang;
            select IDSP as HTKSauKhiThemDGH, * from HangTrongKho;

-- ############################################# Bộ phận kinh doanh ################################################
-- #################################################################################################################
-- #################################################################################################################


    -- Proc Thống kê chung
        -- Kiểm tra Doanh Thu và  trước khi thống kê date: 2025-01-11
        SELECT * FROM ThongKe WHERE NgayThongKe = '2024-11-08'
        -- thực thi store procedure
        DECLARE @DT FLOAT;
        DECLARE @SLKH FLOAT;

        EXEC ThongKeChung
		        @ngayTK = '2024-11-08',
		        @DT = @DT OUTPUT, 
		        @SLKH = @SLKH OUTPUT;

        -- kiểm tra dữ liệu thống kê sau khi thực thi store procedure
        SELECT ID, NgayThongKe, TongDoanhThu AS DoanhThu_Sau_ThongKe, TongSLKH AS SLKH_Sau_ThongKe
        FROM ThongKe
        WHERE NgayThongKe = '2024-11-08'

        -- kiểm tra ở bảng DonHang
        SELECT * FROM DonHang WHERE NgayMua = '2024-11-08'
        -- check kết quả tổng tiền và tổng số lượng khách hàng so với kết quả trong proc
        SELECT ISNULL(sum(TongTien),0) AS TongDoanhThu, COUNT(DISTINCT IDKH) AS TongSLKH
        FROM DonHang 
        WHERE NgayMua = '2024-11-08'


    -- Proc: Thống kê tùy chọn
        --Trường hợp 1: Thống kê theo tuần,input: ngày bắt đầu 2024-11-05 => tuần thống kê từ 2024-11-04 đến 2024-11-10

            -- kiểm tra dữ liệu Đơn hàng theo tuần: 2024-11-04 đến 2024-11-10
            SELECT * 
            FROM DonHang
            WHERE NgayMua >= '2024-11-11' AND NgayMua <= '2024-11-17'

            -- Thực thi store procedure
            DECLARE @DT FLOAT;
            DECLARE @SLKH FLOAT;

            EXEC ThongKeTuyChon	
	            @kieuThongKe = 'TUAN',
                @ngayBatDau = '2024-11-12',
                @DT = @DT OUTPUT,
                @SLKH = @SLKH OUTPUT;

            -- kết quả:
            SELECT @DT AS DoanhThu, @SLKH AS SoLuongKhachHang;

        --Trường hợp 2: Thống kê theo tháng
            DECLARE @DT FLOAT;
            DECLARE @SLKH FLOAT;

            EXEC ThongKeTuyChon	
	            @kieuThongKe = 'THANG',
                @ngayBatDau = '2024-11-05',
                @DT = @DT OUTPUT,
                @SLKH = @SLKH OUTPUT;

            -- check kết quả:
            SELECT * FROM DonHang 
            WHERE MONTH(NgayMua) = 11 

            SELECT ISNULL(SUM(TongTien), 0) AS DoanhThu, ISNULL(COUNT(DISTINCT IDKH ), 0) AS SLKH
            FROM DonHang
            WHERE MONTH(NgayMua) = 11

        --Trường hợp 3: Thống kê theo khoảng thời gian
            DECLARE @DT FLOAT;
            DECLARE @SLKH INT;

            EXEC ThongKeTuyChon
                @kieuThongKe = 'KHOANG',
                @ngayBatDau = '2024-11-01',
                @ngayKetThuc = '2024-11-08',
                @DT = @DT OUTPUT,
                @SLKH = @SLKH OUTPUT;

            -- Check kết quả:
            SELECT * FROM DonHang
            WHERE NgayMua >= '2024-11-01' AND NgayMua <= '2024-11-08'

            SELECT ISNULL(SUM(TongTien), 0) AS DoanhThu, ISNULL(COUNT(DISTINCT IDKH ), 0) AS SLKH
            FROM DonHang
            WHERE  NgayMua >= '2024-11-01' AND NgayMua <= '2024-11-08'

    --Proc Thống kê sản phẩm
        --kiểm tra dữ liệu thống kê sản phẩm (trong table ThongKeSP) trước khi thống kê
            SELECT * 
            FROM ThongKeSP
            WHERE NgayThongKe = '2024-11-07'

        -- thực thi procedure
            EXEC ThongKeSanPham @ngayTK = '2024-11-07'



