create database supermarket_HQTCSDL;
use supermarket_HQTCSDL;

create table KhachHang(
  SDT varchar(15) not null ,
  NgaySinh date not null ,
  NgayDangKy date not null ,
  LoaiKH nvarchar(20) ,
  TongTienMua int default 0,
  Voucher bit default 0,
  primary key(SDT),
)
create table LoaiKhachHang(
  Ten nvarchar(20),
  UuDai int not null ,
  NguongTren int not null ,
  primary key(Ten),
)
create table DonHang(
    ID int IDENTITY(1,1),
    NgayMua datetime not null ,
    TongGiamGia int default 0,
    TongTien int,
    TrangThai nvarchar(30) not null ,
    IDKH varchar(15),
    primary key (ID),
)
create table CTDH(
     ID int IDENTITY(1,1),
     IDSP int not null ,
     IDDH int  not null ,
     SL int not null ,
     Gia int not null ,
     IDCTKM int,
     primary key (ID),
)
create table LoaiSanPham(
    Ten nvarchar(20),
    primary key (Ten),
)
create table SanPham(
    ID int identity(1,1),
    TenSP nvarchar(50) not null ,
    NgaySanXuat date not null ,
    PhanLoai nvarchar(20),
    GiaNiemYet int not null ,
    primary key (ID),
)
create table HangTrongKho(
     IDSP int not null ,
     SLSPTD int not null ,
     SPSPTK int not null ,
     primary key (IDSP),
)
create table DonDatHang(
   ID int identity(1,1),
   SL int not null ,
   SLDuocGiao int default 0,
   NgayDat datetime not null ,
   TrangThai nvarchar(10) default 'Chưa Giao',
   IDHTK int not null ,
   IDDGH int,
   primary key (ID),
)
create table DonGiaoHang(
    ID int identity(1,1),
    NgayGiao datetime not null ,
    TrangThai nvarchar(10) not null ,
    primary key (ID),
)
create table ThongKeSP(
  ID int identity(1,1),
  NgayThongKe date not null ,
  SLDaBan int not null ,
  SLKHDatMua int not null ,
  IDSP int not null ,
  primary key (ID),
)
create table ThongKe(
    ID int identity (1,1),
    NgayThongKe date not null ,
    TongDoanhThu int not null ,
    TongSLKH int not null ,
    primary key (ID),
)
create table CTKM(
     ID int identity(1,1),
     ThoiGianBatDau date not null ,
     ThoiGianKetThuc date not null ,
     KhaDung bit default 1,
     LoaiSale nvarchar(20) not null ,
     primary key (ID),
)
create table CTCTKMFlashSale(
    IDSP int not null ,
    IDCTKM int not null ,
    SLKM int not null ,
    PhanTramKM int not null ,
    KhaDung bit default 1,
    primary key (IDCTKM, IDSP),
)
create table CTCTKMComboSale(
    IDSP1 int default 0,
    IDSP2 int default 0,
    IDCTKM int not null ,
    SLKM int not null ,
    PhanTramKM int not null ,
    KhaDung bit default 1,
    primary key (IDCTKM, IDSP1, IDSP2),
)
create table CTCTKMMemberSale(
     IDSP int not null ,
     IDCTKM int not null ,
     SLKM int not null ,
     KhaDung bit default 1,
     primary key (IDCTKM, IDSP),
)
create table CTUuDaiMemberSale(
  ID int identity (1,1),
  IDCTKM int not null ,
  IDSP int not null ,
  LoaiKhachHang nvarchar(20) not null ,
  PhanTramKM int not null ,
  primary key (ID),
)
alter table KhachHang add foreign key (LoaiKH) references LoaiKhachHang(Ten)
    on delete set null on update cascade;
alter table DonHang add foreign key (IDKH) references KhachHang(SDT)
    on delete cascade on update cascade;
alter table CTDH add foreign key (IDSP) references SanPham(ID)
    on delete cascade on update cascade;
alter table CTDH add foreign key (IDDH) references DonHang(ID)
    on delete cascade on update cascade;
alter table SanPham add foreign key (PhanLoai) references LoaiSanPham(Ten)
    on delete set null on update cascade;
alter table ThongKeSP add foreign key (IDSP) references SanPham(ID);
alter table HangTrongKho add foreign key (IDSP) references SanPham(ID)
    on delete cascade on update cascade;
alter table DonDatHang add foreign key (IDHTK) references HangTrongKho(IDSP)
    on delete cascade on update cascade;
alter table DonDatHang add foreign key (IDDGH) references DonGiaoHang(ID)
    on delete cascade on update cascade;
alter table CTCTKMFlashSale add foreign key (IDSP) references SanPham(ID)
    on delete cascade on update cascade;
alter table CTCTKMFlashSale add foreign key (IDCTKM) references CTKM(ID)
    on delete cascade on update cascade;
alter table CTCTKMComboSale add foreign key (IDCTKM) references CTKM(ID)
    on delete cascade on update cascade;
alter table CTCTKMComboSale add foreign key (IDSP1) references SanPham(ID)
alter table CTCTKMComboSale add foreign key (IDSP2) references SanPham(ID)
alter table CTCTKMMemberSale add foreign key (IDSP) references SanPham(ID)
    on delete cascade on update cascade;
alter table CTCTKMMemberSale add foreign key (IDCTKM) references CTKM(ID)
    on delete cascade on update cascade;
alter table CTUuDaiMemberSale add foreign key (IDCTKM, IDSP) references CTCTKMMemberSale(IDCTKM, IDSP)
    on delete cascade on update cascade;
alter table CTUuDaiMemberSale add foreign key (LoaiKhachHang) references LoaiKhachHang(Ten)
    on delete cascade on update cascade;