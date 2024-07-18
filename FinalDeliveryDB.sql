USE [master]
GO

/*******************************************************************************
   Drop database if it exists
********************************************************************************/
IF EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE name = N'PE_DBI202_Su2024')
BEGIN
	ALTER DATABASE DeliveryDB SET OFFLINE WITH ROLLBACK IMMEDIATE;
	ALTER DATABASE DeliveryDB SET ONLINE;
	DROP DATABASE DeliveryDB;
END

GO
CREATE DATABASE DeliveryDB
GO

use DeliveryDB

--CREATE TABLE

--Addresses
create table Addresses(
addrID int identity(1,1),
province nvarchar(20) not null,
district nvarchar(20) not null,
town nvarchar(20) not null,
addrDetail nvarchar(100) not null,
primary key(addrID)
)

--Hubs
create table Hubs(
	hubID int identity(1,1),
	hubName nvarchar(20) not null,
	addrID int not null,
	managerID int,			
	primary key(hubID),
	foreign key(addrID)references Addresses(addrID),
)
--Employees
create table Employees(
	empID int identity(1,1),
	empName nvarchar(50) not null,
	empSSN char(12) unique not null,
	empDoB date not null,
	empPhone char(10) unique not null,
	empEmail varchar(50) unique,
	hubID int not null,
	baseSalary decimal(12,2) default(0),
	[role] nvarchar(20) not null,
	primary key(empID),
	foreign key(hubID)references Hubs(hubID),
	check (empSSN like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
	check (empPhone like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
	check (empEmail like '%_@gmail.com'),
	check ([role] in ('Manager','Assistant','Shipper')),
	check (baseSalary>=4000)
)

--Connect managerID in Hubs
alter table Hubs
add foreign key(managerID)references Employees(empID)

--Customers
create table Customers(
	cusID int identity(1,1),
	cusName nvarchar(50)not null,
	cusPhone char(10) unique not null,
	cusDoB date,
	cusEmail varchar(50) unique,
	addrID int,
	foreign key(addrID) references Addresses(addrID),
	primary key(cusID),
	check (cusPhone like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
	check (cusEmail like '%_@gmail.com')
)

--Receivers
create table Receivers(
	rcvID int identity(1,1),
	rcvName nvarchar(50)not null,
	rcvPhone char(10) unique not null,
	addrID int,
	foreign key(addrID) references Addresses(addrID),
	primary key(rcvID),
	check (rcvPhone like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
)

--Categories
create table Categories(
	ctgID int identity(1,1),
	ctgName nvarchar(20)not null,
	ctgDetail nvarchar(100)not null,
	costFactor float not null,
	primary key(ctgID),
	check (costFactor>=1)
)

--Provider
create table Providers(
	prvID int identity(1,1),
	prvName nvarchar(50)not null,
	discount decimal(12,2) not null default(0),
	primary key(prvID),
	check (discount between 0 and 1)
)

--ItemModels
create table ItemModels(
	itmID  int identity(1,1),
	itmName nvarchar(30)not null,
	itmDetail nvarchar(100),
	[weight] decimal(12,2) not null,
	ctgID int not null,
	prvID int,
	primary key(itmID),
	foreign key(ctgID)references Categories(ctgID),
	foreign key(prvID)references Providers(prvID),
	check ([weight]>0)
)

--Orders
create table Orders(
	ordID int identity(1,1),
	cusID int not null,
	rcvID int not null,
	typeOfOrd nvarchar(20)not null,
	COD int not null default(0),
	fromAddrID int not null,
	toAddrID int not null,
	distance float not null,
	timeOrdered datetime,
	shipperID int,
	timeArrived datetime,
	rating int,
	cost float,
	primary key(ordID),
	foreign key(cusID) references Customers(cusID),
	foreign key(rcvID) references Receivers(rcvID),
	foreign key(fromAddrID)references Addresses(addrID),
	foreign key(toAddrID)references Addresses(addrID),
	foreign key(shipperID)references Employees(empID),
	check (COD between 0 and 1000000),
	check (rating between 0 and 5),
	check (distance>0 and distance<=60),
	check (typeOfOrd in ('Normal','Fast','Fastest'))
)

--Orders contain ItemModels
create table contain(
	ordID int,
	itmID int,
	numOfItem int not null,
	primary key(ordID,itmID),
	foreign key(ordID)references Orders(ordID),
	foreign key(itmID)references ItemModels(itmID),
	check (numOfItem>0)
)

go

--CREATE TRIGGER FUNCTION PROCEDURE
CREATE FUNCTION employeeMonthlySalary(@Hub INT, @MONTH INT,@YEAR INT)
RETURNS TABLE
AS
RETURN(
	SELECT empID,e.empSSN,empName,empEmail,empPhone, (baseSalary*100 + SUM( 0.5 * o.cost )) AS SalaryOfMonth FROM Employees e JOIN Orders o ON e.empID = o.shipperID 
	WHERE hubID = @Hub AND MONTH(o.timeArrived) = @MONTH AND o.timeArrived IS NOT NULL AND YEAR(o.timeArrived) = @YEAR
	GROUP BY empID,e.empSSN,empName,empEmail,empPhone,baseSalary

)
go

--SELECT * FROM dbo.employeeMonthlySalary(1,1,2024)

CREATE FUNCTION orderHasNotBeenShipped(@Hub INT)
RETURNS TABLE
AS
RETURN(
	SELECT ordID,o.rcvID, o.COD, o.cost,o.fromAddrID,(a1.addrDetail + ' ' + a1.town + ' '+  a1.province + ' ' + a1.district) AS [AddressFrom],
	(a2.addrDetail + ' ' + a2.town + ' '+  a2.province + ' ' + a2.district) AS [AddressTo],
	e.empName AS ShipperName 
	FROM Orders o JOIN Employees e ON e.empID = o.shipperID
	JOIN Addresses a1 ON a1.addrID = o.fromAddrID JOIN Addresses a2 ON a2.addrID = o.toAddrID WHERE o.timeArrived IS NULL AND e.hubID = @Hub
)
go

--SELECT * FROM dbo.orderHasNotBeenShipped(2)
go

CREATE PROC revenueOfMonth
@Month INT,
@Year INT,
@TotalCostOrders int OUTPUT
AS
BEGIN
	SELECT @TotalCostOrders = SUM(cost) FROM Orders
	WHERE MONTH(timeArrived) = @Month AND YEAR(timeArrived) = @Year
END
--SELECT * FROM Orders
--DECLARE @x INT
--EXEC revenueOfMonth 1,2024,@x OUTPUT
--SELECT @x AS TotalCostOrders 
go

CREATE PROCEDURE profitOfMonth
    @Month INT,
    @Year INT,
    @profit INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TotalCost DECIMAL(18, 2);
    DECLARE @TotalSalary DECIMAL(18, 2);
    DECLARE @BaseSalary DECIMAL(18, 2);
    SELECT @TotalCost = SUM(o.cost) FROM Orders o WHERE MONTH(o.timeArrived) = @Month AND YEAR(o.timeArrived) = @Year; 
	WITH CTE AS (
    SELECT e.empID, e.empSSN,e.empName,e.empEmail,e.empPhone,
        (e.baseSalary + SUM(0.5 * o.cost)) AS SalaryOfMonth
    FROM Employees e
    JOIN Orders o ON e.empID = o.shipperID
    WHERE MONTH(o.timeArrived) = @Month AND o.timeArrived IS NOT NULL AND YEAR(o.timeArrived) = 2024
    GROUP BY e.empID, e.empSSN,e.empName, e.empEmail,e.empPhone,e.baseSalary
)

SELECT @TotalSalary = SUM(SalaryOfMonth) 
FROM CTE;
   SET @profit = @TotalCost - @TotalSalary;
    SELECT @profit AS ProfitOfMonth;
END

--DECLARE @x INT
--EXEC profitOfMonth 1,2024,@x OUTPUT
--SELECT @x AS profitOfMonth
go

CREATE TRIGGER changePosition
ON Employees
INSTEAD OF UPDATE
AS
BEGIN
    DECLARE @role NVARCHAR(50)
    DECLARE @manager INT
    SELECT @role = i.role FROM inserted i
    SELECT @manager = i.empID FROM inserted i
    IF EXISTS (SELECT hubID FROM Hubs WHERE managerID = @manager)
    BEGIN
        UPDATE Hubs
        SET managerID = NULL
        WHERE hubID IN (SELECT hubID FROM Hubs WHERE managerID = @manager)
    END
	ELSE IF (NOT EXISTS(SELECT hubID FROM Hubs WHERE managerID = @manager) AND @role = 'Manager' )
	BEGIN
		UPDATE Hubs
		SET managerID = @manager
		WHERE hubID = (SELECT i.hubID FROM inserted i)
	END
    UPDATE e
    SET e.role = @role
    FROM Employees e
    JOIN inserted i ON e.empID = i.empID
END

--UPDATE Employees
--SET role = 'Manager'
--WHERE empID = 4
--SELECT * FROM Hubs
--SELECT * FROM Employees
go

CREATE TRIGGER getDateOrder
ON Orders
AFTER INSERT
AS
BEGIN
	DECLARE @getdateauto DATETIME
	SELECT @getdateauto = GETDATE()
	UPDATE Orders
	SET timeOrdered = @getdateauto
	WHERE ordID in (SELECT i.ordID FROM inserted i where i.timeOrdered is null)
END
--SELECT * FROM Orders
--insert into Orders (cusID, rcvID, typeOfOrd, COD, fromAddrID, toAddrID, distance, timeOrdered, shipperID,  rating, cost)
--values 
--(1, 2, 'Normal', 50000, 25, 29, 10.5, '2024-01-10 08:30:00', 1, 4, 30000)
go

--INSERT VALUE

--Insert data into the Addresses table

--Hanoi
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Ba Đình', N'Kim Mã', N'290 Kim Mã');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội',N'Hoàn Kiếm', N'Lý Thường Kiệt', N'48 Lý Thường Kiệt');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Ba Đình',N'Núi Trúc', N'2 Núi Trúc');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Ba Đình', N'Phan Đình Phùng', N'20 Phan Đình Phùng');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Ba Đình', N'Kim Mã Thượng', N'28 Kim Mã Thượng');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Ba Đình', N'Đội Cấn', N'64 Đội Cấn');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Đống Đa', N'Đặng Văn Ngữ', N'Ngõ 4A Đặng Văn Ngữ');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Hoàn Kiếm', N'Quang Trung', N'64 Quang Trung');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Thanh Xuân', N'Khuất Duy Tiến', N'76 Khuất Duy Tiến');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Hoàng Mai', N'Kim Giang', N'25 Kim Giang');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Thanh Xuân', N'Lê Văn Lương', N'21 Lê Văn Lương');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Thanh Xuân', N'Lê Trọng Tuấn', N'66 Lê Trọng Tuấn');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Hoàn Kiếm', N'Hàng Đậu', N'50B Hàng Đậu');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Đống Đa', N'Thái hà', N'Ngõ 133 Thái hà');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Đống Đa', N'Tây Sơn', N'Ngõ 167 Tây Sơn');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Thanh Xuân', N'Nguyễn Trãi', N'111 Nguyễn Trãi');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Nam Từ Liêm', N'Nhuệ Giang', N'22 Nhuệ Giang');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Hoàng Mai', N'Dương Văn Bé', N'64 Dương Văn Bé');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Hoàn Kiếm', N'Lò Rèn', N'88 Lò Rèn');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Hoàn Kiếm', N'Bát Đàn', N'55 Bát Đàn');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Nam Từ Liêm', N'Đình Thôn', N'94 Nhuệ Giang');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Bắc Từ Liêm', N'Xuân Đỉnh', N'Ngõ 401 Xuân Đình');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Hà Nội', N'Hoàng Mai', N'Giáp Bát', N'79 Giáp Bát');
go

-- TP.HCM

INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận 1', N'Trần Quang Khải', N'30 Trần Quang Khải');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận 12', N'Thạnh Lộc', N'39A Hà Huy Giáp');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận 1', N'Bến Nghé', N'Số 72A Lê Thánh Tông ');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận 12', N'Thạnh Xuân', N'12 Thạnh Xuân');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận 2', N'Cát Lái', N'707 NGuyễn Thị Định');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận 2', N'Bình An', N'Số 43/15 Đường 38');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận 2', N'Thảo Điền', N'02 Nguyễn Bá Huân');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận 1', N'Nguyễn Cư Trinh', N'235 đường Nguyễn Văn Cừ');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận Binh Thanh', N'Phường 22', N'208 Nguyễn Hữu Cảnh');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận 3', N'Võ Thị Sáu', N'87 Bà Huyện Thanh Quan');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận 3', N'Phường 7', N'6A Ngô Thời Nhiệm');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận Bình Thạnh', N'Phường 27', N'31 Thanh Đa');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận Phú Nhuận', N'Phường 2', N'Phan Xích Long');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận Phú Nhuận', N'Phường 9', N'202 Hoàng Văn Thụ');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận Tân Phú', N'Phú Thạnh', N'215 Trần Thủ Độ');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận Gò Vấp', N'Phường 17', N'37 Nguyễn Văn Lượng');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận Thủ Đức', N'Bình Thọ', N'Số 1 đường Tagore');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận Bình Tân', N' Bình Trị Đông A', N'Số 809, Đường Hương Lộ 2');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'TP.HCM', N'Quận Nhà Bè', N'Phú Xuân', N'330 đường Nguyễn Bình');
go

--Da Nang 

INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Hải Châu', N'Hòa Cường Bắc', N' 01 Phan Đăng Lưu');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Thanh Khê', N'Chính Gián', N'3 Lê Duẩn');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Sơn Trà', N'Mai Hắc Đế', N'22 Mai Hắc Đế');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Ngũ Hành Sơn', N'Hòa Hải', N'số 81, đường Huyền Trân Công Chúa');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Liên Chiểu', N'Hòa Khánh Nam', N'525 Tôn Đức Thắng');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Cẩm Lệ', N'Khuê Trung', N'71 Đường Xuân Thủy');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Hòa Vang', N'Hoà Phước', N'22 Miếu Bông 5');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Hải Châu', N'Hùng Vương', N'290 Hùng Vương');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Thanh Khê', N'Thạc Gián', N'46 Phan Thanh');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Sơn Trà', N'An Hải Bắc', N'08 Phạm Thiều');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Ngũ Hành Sơn', N'Khuê Mỹ', N'6 Chu Cẩm Phong');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Liên Chiểu', N'Hòa Minh', N'403 Tôn Đức Thắng');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Cẩm Lệ', N'Khuê Trung', N' 115-117 Đỗ Thúc Tịnh');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Hòa Vang', N'Hoà Phước', N'Giáng Nam 1');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Hải Châu', N'Hòa Cường Bắc', N'Đường 2 tháng 9');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Thanh Khê', N'Thạc Gián', N'17 Trần Tống');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Sơn Trà', N'An Hải Bắc', N'128 Hoàng Bích Sơn');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Ngũ Hành Sơn', N'Lê Văn Hiến', N'486 Lê Văn Hiến');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Liên Chiểu', N'Hoà Khánh Nam', N'Trà Na 2');
INSERT INTO Addresses(province, district, town, addrDetail) VALUES (N'Đà Nẵng', N'Cẩm Lệ', N'Khuê Trung', N'40 Đường Ông Ích Đường');
go

--select * from Addresses

INSERT INTO Hubs(hubName, addrID, managerID)  VALUES 
(N'Hà Nội Hub',1,null),
(N'Đà Nẵng Hub',20,null),
(N'Hà Nội Hub',51,null),
(N'TP.HCM Hub',56,null)
go

--select * from Employees

INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Phan Quang Giáp','001204241123', '2004-01-01', '0678234190', 'giapsmith456@gmail.com',1, 9000, 'Manager')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Đào Việt Tùng','001204567126', '2004-08-27', '0289047563', 'davidtung789@gmail.com', 1, 6500, 'Assistant')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Phạm Gia Khải','001232343553', '2004-12-23', '0934672185', 'khaiemily1234@gmail.com', 1, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Trần Xuân Huy','001204223521', '2004-09-19', '0775432109', 'huygreen333@gmail.com', 1, 4500 ,'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Phạm Thành Công', '001204116922', '2004-02-27', '0779138827', 'congconhavesinh@gmail.com', 2, 9000, 'Manager')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Nguyễn Thị Lan', '005992384474', '2004-04-10', '0779138829', 'lannguyen@gmail.com', 2, 6500, 'Assistant')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Lê Văn An', '005151506879', '2004-05-22', '0779138830', 'anle@gmail.com', 2, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Vũ Thị Hà', '004072732370', '2004-06-18', '0779138831', 'havt@gmail.com', 2, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Hoàng Văn Hùng', '005248423902', '2004-07-14', '0779138832', 'hungv@gmail.com', 1, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Phan Thị Minh', '006743234626', '2004-08-09', '0779138833', 'minhphan@gmail.com', 1, 6500, 'Assistant')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Tạ Văn Bình', '008410231621', '2004-09-23', '0779138834', 'binhta@gmail.com', 1, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Đỗ Thị Mai', '001957864630', '2004-10-30', '0779138835', 'maidothi@gmail.com', 2, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Trương Văn Hải', '004617193943', '2004-11-16', '0779138836', 'haitruong@gmail.com', 1, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Ngô Thị Tâm', '001695369654', '2004-12-25', '0779138837', 'tamngo@gmail.com', 1, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Trịnh Văn Phúc', '006875539120', '2005-01-01', '0779138838', 'phuctrinh@gmail.com', 3, 4500, 'Manager')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Bùi Thị Dung', '007996690960', '2005-02-14', '0779138839', 'dungbui@gmail.com', 3, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Phạm Văn Sơn', '007959072895', '2005-03-20', '0779138840', 'sonpham@gmail.com', 3, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Lương Thị Thu', '001204116936', '2005-04-28', '0779138841', 'thuluong@gmail.com', 3, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Phùng Văn Tài', '004780398876', '2005-05-06', '0779138842', 'taiphung@gmail.com', 2, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Tô Thị Minh', '003863159459', '2005-06-13', '0779138843', 'minhto@gmail.com', 1, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Lê Văn Hải', '004696569405', '2005-07-19', '0779138844', 'haile@gmail.com', 4, 4500, 'Manager')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Trần Thị Hoài', '000422218417', '2005-08-25', '0779138845', 'hoaitran@gmail.com', 4,4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Nguyễn Văn Minh', '009582465866', '2005-09-01', '0779138846', 'minhnguyen@gmail.com', 4, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Đào Thị Thu', '001204116942', '2005-10-12', '0779138847', 'thudao@gmail.com', 4, 4500, 'Shipper')
INSERT INTO Employees (empName, empSSN, empDoB, empPhone, empEmail, hubID, baseSalary, [role]) VALUES (N'Phạm Văn Nam', '001695368543', '2005-11-22', '0779138848', 'nampham@gmail.com', 4, 4500, 'Shipper')
go

--update manager

UPDATE Hubs
SET managerID = 1
WHERE hubName = N'Hà Nội Hub' and hubID = 1

UPDATE Hubs
SET managerID = 5
WHERE hubName = N'Đà Nẵng Hub' and hubID = 2

UPDATE Hubs
SET managerID = 14
WHERE hubName = N'Hà Nội Hub' and hubID = 51
go
 
--Categories
insert into Categories (ctgName, ctgDetail, costFactor)
values
(N'Dễ Vỡ',N'Cẩn thận lúc vận chuyển', 1.5),
(N'Đông Lạnh', N'Chú ý ướp lạnh trước khi vận chuyển', 1.3),
(N'Tươi Sống', N'Cần được bảo quản kĩ càng, không xếp chồng lên nhau', 1.5),
(N'Dễ Cháy',N'Tránh những vật dụng dễ cháy nổ tiếp xúc', 2.0),
(N'Quần Áo',N'Tránh Ẩm, Đặt hướng lên', 1.2),
(N'Lương thực',N'Tránh những chỗ ẩm thấp', 1.2),
(N'Y tế và dược phẩm',N'Cẩn thận lúc vận chuyển', 1.3),
(N'Sách báo',N'Tránh nơi ẩm thấp', 1.4)
--select * from Employees
go

--providers 
insert into Providers(prvName,discount)
values
(N'Công ty TNHH Samsung Electronics',0.1),
(N'Công ty Cổ phần thương mại thiết bị y tế Vĩnh Phúc',0.25),
(N'Công ty cổ phần chăn nuôi C.P. Việt Nam',0.15),
(N'Uniqlo Vietnam CO., LTD',0.3),
(N'Nhà xuất bản Giáo dục Việt Nam',0.6)
go

--ItemModel
insert into ItemModels(itmName,itmDetail,weight,ctgID,prvID)
values
(N'Smart Tivi 4K',N'Smart Tivi Samsung 4K 43 inch UA43CU8000',8.4,1,1),
(N'Xúc xích Phô Mai',N'Xúc xích Phô Mai CP được làm từ thịt lợn và thịt bò',0.5,2,3),
(N'Cồn',N'Cồn 70% v/v Ethanol',0.5,4,2),
(N'Áo',N'Áo Thun Cổ Tròn Ngắn Tay Size L Cotton',0.12,5,4),
(N'Cam thung 10kg',N'Cam Sành Hà Giang',10,3,null),
(N'Gạo ST25 5kg',N'Gạo ST25 Gạo Thơm Thượng Hạng',5,6,null),
(N'Điện thoại',N'Samsung Galaxy S24 5G 8GB/256GB',0.196,1,1),
(N'Rau',N'Rau muống trắng',0.3,3,null),
(N'Thuốc đau bụng',N'Thuốc đau bụng Berberin',0.1,7,2),
(N'Sách Giáo Khoa',N'Sách Giáo Khoa Toán 12',0.2,8,5)
go

-- Customers 
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Đỗ Khắc Việt', '0915738297', '2000-04-27', 'viethehe@gmail.com',2)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Lê Thành Nam', '0987654321', '2003-09-07', 'janesmith@gmail.com',4)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Phạm Ngọc Mai', '0968038714', '1999-02-23', 'maimai@gmail.com',6)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Hoàng Thị Hạnh', '0987123456', '1992-11-20', 'hoanghanh@gmail.com',7)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Đỗ Thị Lan', '0912345670', '1987-02-23', 'dolan@gmail.com',10)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Bùi Văn Minh', '0945678901', '1995-09-15', 'buivanminh@gmail.com',22)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Trần Bích', '0914730365', '1990-12-05', 'tranbich@gmail.com',16)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Phan Văn Dũng', '0909876543', '1988-08-30', 'dungphan@gmail.com',26)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Phùng Xuân Chiến', '0909435713', '1999-08-30', 'chienphung@gmail.com',39)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Bùi Thị Vân', '0908901234', '1989-04-15', 'buivan@gmail.com',47)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Đỗ Văn Thắng', '0909012345', '1990-06-25', 'dothang@gmail.com',54)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Phan Thị Thủy', '0910123456', '1994-08-04', 'phanthithuy@gmail.com',45)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Trần Văn Tùng', '0902345678', '1992-03-22', 'tranvantung@gmail.com',24)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Lê Thị Ngọc', '0903456789', '1987-05-30', 'lethingoc@gmail.com',29)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Phạm Thị Hương', '0904567890', '1993-07-08', 'phamthihuong@gmail.com',60)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) values (N'Phan Văn Sơn', '0908765432', '1991-10-10', 'phanson@gmail.com',44)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Trịnh Thị Hiền', '0779138849', '2005-12-15', 'hientrinh@gmail.com', 35)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Lê Văn Đức', '0779138850', '2006-01-07', 'ducle@gmail.com', 37)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Nguyễn Thị Mai', '0779138851', '2006-02-19', 'mainhuyen@gmail.com', 50)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Phạm Thị Lan', '0779138852', '2006-03-21', 'lanpham@gmail.com', 33)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Trần Văn Bình', '0779138853', '2006-04-05', 'binhtran@gmail.com', 7)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Phan Thị Hoa', '0779138854', '2006-05-15', 'hoaphan@gmail.com', 57)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Nguyễn Văn Hưng', '0779138855', '2006-06-18', 'hungnguyen@gmail.com', 5)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Trần Thị Thảo', '0779138856', '2006-07-10', 'thaotran@gmail.com',8)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Lê Văn Cường', '0779138857', '2006-08-02', 'cuongle@gmail.com', 9)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Phan Văn Long', '0779138865', '2007-04-11', 'longphan@gmail.com', 27)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Tạ Thị Vân', '0779138866', '2007-05-19', 'vantta@gmail.com', 14)
insert into Customers (cusName, cusPhone, cusDoB, cusEmail,addrID) VALUES (N'Lê Văn Đông', '0779138867', '2007-06-28', 'dongle@gmail.com', 19)
go

--Receivers
insert into Receivers (rcvName, rcvPhone,addrID)
values 
(N'Nguyễn Thị Thu', '0912345678',29),
(N'Trần Văn Bình', '0923456789',3),
(N'Lê Thị Hồng', '0934567890',4),
(N'Phạm Văn Quý','0973481903',5),
(N'Hoàng Thị Lan', '0956789012',19),
(N'Vũ Văn Kiên', '0967890123',24),
(N'Đặng Thị Mai', '0978901234',1),
(N'Bùi Văn Nam', '0989012345',22),
(N'Đỗ Thị Phương', '0990123456',40),
(N'Phan Văn Tài', '0901234567',41);
go

-- Orders 3 4 7 8 9 11 12 13 14 15 16 17 18 19 21 22 23 24
insert into Orders (cusID, rcvID, typeOfOrd, COD, fromAddrID, toAddrID, distance, timeOrdered, shipperID, timeArrived, rating, cost) values 
(1, 1, 'Normal', 50000, 25, 29, 10.5, '2024-01-10 08:30:00', 3, '2024-01-10 09:00:00', 4, 100000),
(1, 2, 'Fast', 200000, 2, 3, 15.0, '2024-01-11 10:00:00', 4, '2024-01-11 10:45:00', 5, 150000),
(2, 3, 'Fastest', 300000, 3, 4, 20.0, '2024-01-12 12:00:00', 3, '2024-01-12 12:30:00', 5, 200000),
(2, 4, 'Normal', 100000, 4, 5, 5.0, '2024-01-13 14:00:00', 7, '2024-01-13 14:15:00', 3, 50000),
(1, 5, 'Fast', 250000, 44, 47, 12.0, '2024-01-14 16:00:00', 8, '2024-01-14 16:30:00', 4, 120000),
(3, 1, 'Normal', 0, 6, 7, 8.0, '2024-01-15 18:00:00', 11, '2024-01-15 18:20:00', null, 80000),
(4, 6, 'Fastest', 150000, 7, 8, 25.0, '2024-01-16 09:00:00', 9, '2024-01-16 09:30:00', 5, 180000),
(3, 7, 'Normal', 50000, 33, 37, 3.0, '2024-01-17 11:00:00', 15, '2024-01-17 11:10:00', null, 30000),
(5, 8, 'Fast', 120000, 50, 52, 18.0, '2024-01-18 13:00:00', 14, '2024-01-18 13:40:00', 4, 160000),
(2, 9, 'Fastest', 60000, 10, 12, 22.0, '2024-01-19 15:00:00', 18, '2024-01-19 15:30:00', 5, 140000),
(6, 10, 'Normal', 70000, 11, 19, 10.0, '2024-01-20 08:00:00', 21, '2024-01-20 08:20:00', 4, 90000),
(2, 4, 'Fast', 0, 7, 19, 14.0, '2024-01-21 10:00:00', 23, '2024-01-21 10:30:00', 5, 110000),
(2, 3, 'Fastest', 50000, 4, 5, 9.5, '2024-01-22 12:00:00', 24, '2024-01-22 12:30:00', 5, 95000),
(7, 9, 'Normal', 150000, 30, 32, 11.0, '2024-01-23 14:00:00', 19, '2024-01-23 14:20:00', null, 130000),
(4, 7, 'Fast', 0, 34, 41, 16.0, '2024-01-24 16:00:00', 13, '2024-01-24 16:40:00', 4, 160000),
(4, 1, 'Normal', 100000, 27, 24, 7.0, '2024-01-25 18:00:00', 12, '2024-01-25 18:15:00', 3, 75000),
(8, 3, 'Fastest', 250000, 8, 9, 19.0, '2024-01-26 09:00:00', 3, '2024-01-26 09:40:00', null, 180000),
(9, 10, 'Normal', 80000, 9, 10, 4.0, '2024-01-27 11:00:00', 8, '2024-01-27 11:20:00', 3, 60000),
(10, 1, 'Fast', 120000, 18, 19, 13.0, '2024-01-28 13:00:00', 9, '2024-01-28 13:35:00', 4, 140000),
(11, 2, 'Fastest', 60000, 55, 60, 21.0, '2024-01-29 15:00:00', 11, '2024-01-29 15:30:00', 5, 130000);
insert into Orders (cusID, rcvID, typeOfOrd, COD, fromAddrID, toAddrID, distance, timeOrdered, shipperID, timeArrived, rating, cost) values (12, 1, 'Normal', 0, 13, 45, 20, '2024-02-01 08:30:00', 24, '2024-02-11 09:00:00', null, 200000)
insert into Orders (cusID, rcvID, typeOfOrd, COD, fromAddrID, toAddrID, distance, timeOrdered, shipperID, timeArrived, rating, cost) values (13, 5, 'Normal', 250000, 10, 19, 16, '2024-02-01 08:30:00', 23, '2024-02-01 09:10:00', 2, 130000)
insert into Orders (cusID, rcvID, typeOfOrd, COD, fromAddrID, toAddrID, distance, timeOrdered, shipperID, timeArrived, rating, cost) values (14, 3, 'Fastest', 50000, 27, 23, 7, '2024-02-02 20:30:00', 17, '2024-01-10 21:40:00', null, 180000)
insert into Orders (cusID, rcvID, typeOfOrd, COD, fromAddrID, toAddrID, distance, timeOrdered, shipperID, timeArrived, rating, cost) values (15, 4, 'Normal', 350000, 24, 13, 15, '2024-02-02 22:30:00', 19, '2024-01-10 23:00:00', 5, 50000)
insert into Orders (cusID, rcvID, typeOfOrd, COD, fromAddrID, toAddrID, distance, timeOrdered, shipperID, timeArrived, rating, cost) values (16, 7, 'Fast', 50000, 19, 33, 13, '2024-02-02 22:30:00', null, null, null, 104000)
insert into Orders (cusID, rcvID, typeOfOrd, COD, fromAddrID, toAddrID, distance, timeOrdered, shipperID, timeArrived, rating, cost) values (13, 6, 'Normal', 260000, 34, 56, 40, '2024-02-03 06:30:00', 19, null, null, 89000)
go ----------------------------------------------------------------------------------------------------------------------------------3 4 7 8 9 11 12 13 14 15 16 17 18 19 21 22 23 24

--contain
insert into contain(ordID,itmID,numOfItem)
values
(1,1,1),
(2,4,10),
(3,5,2),
(4,2,3),
(5,3,4),
(6,2,10),
(7,2,1),
(8,3,3),
(9,5,2),
(10,10,100),
(10,4,2),
(11,1,1),
(12,2,6),
(13,6,5),
(14,7,3),
(15,8,5),
(16,5,2),
(17,4,5),
(18,1,1),
(19,7,2),
(20,3,3),
(21,2,10),
(22,4,5),
(23,7,8),
(24,10,5),
(25,5,5),
(26,2,6)
go