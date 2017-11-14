--step 1
create database PMS
--创建数据库

--************
--建表顺序:
--Stock ==> Product ==> purchaseOrder ==>Department ==>Employee ==> SalesOrder ==>  Customer ==> Vender 



--Stock 表
create TABLE Stock
(
StkName varchar(20),
StkID  char(6) CONSTRAINT pk_StkID PRIMARY KEY not null
CHECK(StkID like 'Stk[0-9][0-9][0-9]'),
StkAddress varchar(60) not null,
StkRestQty int not null
) 
go

--Product表
go
create TABLE Product(
 ProductID char(6) CONSTRAINT pk_ProductID PRIMARY KEY not null 
CHECK(ProductID like'Pro[0-9][0-9][0-9]'),
 Category  varchar(10)  not null,
 ProductName varchar(30) not null,
 InfoInDetail varchar(50) not null,
 StkID char(6) CONSTRAINT fk_StkID_usedbyProduct REFERENCES Stock(StkID)
)
go


--PurchaseOrder 表
create TABLE PurchaseOrder(
PurchaseOrderID char(6) CONSTRAINT pk_PurchaseOrderID PRIMARY KEY not null 
 CHECK (PurchaseOrderID like 'P[0-9][0-9][0-9][0-9][0-9]') ,
ProductID char(6) CONSTRAINT fk_ProductID REFERENCES Product(ProductID) not null,
Qty int CONSTRAINT chk_Qty CHECK(Qty>=0) not null,
PurchaseDate datetime
)
go



--Department表
create TABLE Department(
DepartmentID char(6) CONSTRAINT pk_DepartmentID PRIMARY KEY
CHECK(DepartmentID like'Dpt[0-9][0-9][0-9]'),
DepartmentName nvarchar(20)

)
go

--Employee 表
create TABLE  Employee(
EmployeeID char(6) CONSTRAINT pk_EmployeeID PRIMARY KEY not null
CHECK(EmployeeID like'Emp[0-9][0-9][0-9]'),
EmployeeName varchar(20) not null,
BirthDate datetime,
HireDate datetime,
LeftDate datetime,
Designation varchar(30),
ResignFlag int,
DepartmentID char(6) CONSTRAINT fk_DepartmentID_UsedbyEmployee REFERENCES Department(DepartmentID)
)
go


--SalesOrder表
create TABLE SalesOrder(
SalesOrderID char(6) CONSTRAINT pk_SalesOrderID PRIMARY KEY 
CHECK (SalesOrderID like 'S[0-9][0-9][0-9][0-9][0-9]'),
SalesQty int CONSTRAINT De_SalesQty DEFAULT 0,
SalesDate datetime,
UnitPrice Decimal(18,2) not null,
ProductID char(6) CONSTRAINT fk_ProductID_usedbySalesOrder REFERENCES Product(ProductID),
EmployeeID char(6) CONSTRAINT fk_EmployeeID_usedbySalesOrder REFERENCES Employee(EmployeeID)
)




--Customer 表
create TABLE Customer(
CustomerID char(6) CONSTRAINT pk_CustomerID PRIMARY KEY not null
CHECK(CustomerID like 'Cst[0-9][0-9][0-9]'),
CustomerName nvarchar(20) not null,
AccountNumber int not null,
PurchasingDate datetime,
Address nvarchar(50),
SalesOrderID char(6) CONSTRAINT fk_SalesorderID_usedbyCustomer REFERENCES SalesOrder(SalesOrderID)
)
go

go
--Vender 表
create TABLE Vender(
VenderID char(6) CONSTRAINT pk_VENDERID PRIMARY KEY not null
CHECK(VenderID like'Ven[0-9][0-9][0-9]'),
StandardPrice Decimal(18,2),
InStockDate datetime ,CONSTRAINT ck_in_out CHECK(InStockDate<OutStockDate),
OutStockDate datetime,
VenderQty int,
LastReceiptPrice Decimal(18,2),
VenderAddress varchar(50),
PurchaseOrderID char(6) CONSTRAINT fk_PurchaseOrderID_usedbyVender REFERENCES PurchaseOrder(PurchaseOrderID)
)
go

create TABLE Salary(
EmployeeID char(6) CONSTRAINT fk_EmployeeID_usedbySalary REFERENCES Employee(EmployeeID),
[Year] int,
[Month] int,
Amount decimal(18,2)
)


------------------------------------------------
------------------------------------------------
------------------------------------------------

--step2

--当产品售出或购入时，库存必须相应地进行更新
create trigger AddP on Purchase.PurchaseOrder
for insert as
begin  
DECLARE @qty INT
SELECT @qty=QTY FROM inserted
 print @qty
update	Product.Stock set product.Stock.StkRestQty=product.Stock.StkRestQty+@qty from product.Stock
where  Stock.StkID=(select StkID from Product.Product join inserted on inserted.ProductID=Product.ProductID)
end
go

CREATE trigger CancelP on Sales.SalesOrder for insert
as
declare @salesqty int 
select @salesqty=salesqty from inserted
begin  update Product.Stock set StkRestQty=Stock.StkRestQty - @salesqty from Product.Stock 
  where Stock.StkID=(select StkID from Product.Product join inserted on inserted.ProductID=Product.ProductID)
end


--员工的退休年龄需要根据其职位自动添加
create trigger leftdate on Employee.Employee
after insert as
begin
declare @ID VARCHAR(6)
select @ID= EmployeeID from inserted
update Employee.Employee set Leftdate=case designation
when 'Manager' then dateadd(yy,+60,BirthDate)
when 'Clerk' then dateadd(yy,+65,BirthDate )
when 'Salesman' then dateadd(yy,+50,birthdate )
     end where EmployeeID=@ID
end

--SAZ 安全仅招收毕业生，因此新员工必须是毕业生，且在加入公司时，年龄至少为22
create trigger  emp_insert on Employee.Employee for insert as
declare @birthdate datetime
select @birthdate=birthdate from Employee.Employee
declare @HireDate datetime
select @HireDate=HireDate from Employee.Employee
if (datediff(yy,@birthdate,@HireDate)<22)
begin print('年龄未达标')
rollback tran
end

--当员工辞职时，记录必须存到员工历史表
create proc EmployeeHistory as
select *from Employee.Employee where ResignFlag=2



--销售人员的工资为基本工资+提成（根据每月是否完成销售指标）
create proc SalesPersonSalary as
begin
With SalaryCTE(EmpId,Year,Month,Amount) 
as (
select EmployeeID,year(SalesDate),month(SalesDate),sum(SalesQty*UnitPrice)as Amount
from Sales.SalesOrder group by EmployeeID,year(SalesDate),month(SalesDate)
)
insert into Employee.Salary  select aa.EmpId,aa.Year,aa.Month,aa.Amount  from (select EmpId,Year,Month,Amount=(
case  
when Amount<5000 then Amount*0.02+2000
when Amount>=5000 and Amount<=6000 then Amount*0.05+2000
when Amount>6000 and Amount<=10000 then Amount*0.08+2000
when Amount>10000 then Amount*0.1+2000 
end)
from SalaryCTE) as aa
end
------------------------------------------------
------------------------------------------------
------------------------------------------------

--step3

/*select * from Employee.Department
select * from Employee.Employee
select * from Product.Product
select * from Purchase.PurchaseOrder
select * from Sales.SalesOrder
select * from product.Stock
select * from Purchase.Vender
SELECT * FROM Sales.Customer
*/
--对于月平均销售量的存储过程
go
create procedure MonthlyAvg(@y int)
as
begin
select '月平均'=sum(UnitPrice*salesQty)/count(DATEPART(mm,salesDate)) from Sales.SalesOrder 
where DATEPART(yy,salesDate)=@y
select '月份'=DATEPART(mm,salesdate),'月总额'=sum(salesqty*unitprice) from Sales.SalesOrder
where DATEPART(yy,salesdate)=@y group by DATEPART(mm,salesdate)
end
go

--exec MonthlyAvg 5
--月总量
go
create proc Monthly_Total(@y int)
as
begin
select '月份'=DATEPART(mm,salesdate),'月总额'=sum(salesqty*unitprice) from Sales.SalesOrder
where DATEPART(yy,salesdate)=@y group by DATEPART(mm,salesdate)
end
go
exec Monthly_Total 1

--求最大销售额
go
create proc Max_ProdAmount
as
begin
select top 1 productID,'销售额'=sum(salesqty*Unitprice) from Sales.SalesOrder 
group by productID order by sum(salesqty*Unitprice) desc
end
go
--exec Max_ProdAmount

--求最小销售额
go
create proc Min_ProdAmount
as
begin
select top 1 productID,'销售额'=sum(salesqty*Unitprice) from Sales.SalesOrder 
group by productID order by sum(salesqty*Unitprice)
end
go
--exec Min_ProdAmount

--求指定年份的销售细节
go
create procedure ProdAmountInYear(@y int)
as
begin
select * from Sales.SalesOrder where DATEPART(yy,SalesDate)=@y
end
go
--exec ProdAmountInYear 1


--制定月份的销售细节
go
create procedure ProdAmountInMonth(@m int)
as
begin
select * from Sales.SalesOrder where DATEPART(mm,SalesDate)=@m
end
go
--exec ProdAmountInMonth 1


--每月的销售额
go
create procedure EveryMonthAmount(@Y INT)
as
begin
select productid,DATEPART(mm,salesdate),SUM(salesqty*unitprice) from 
Sales.SalesOrder group by rollup(productid,DATEPART(mm,salesdate)) having DATEPART(mm,salesdate)=@Y
select '年总额'=sum(salesqty*unitprice) from Sales.salesorder where datepart(yy,salesdate)=@y
end
go

--exec EveryMonthAmount 1


--检索出优秀员工（销售额在平均销售额以上）
go
create procedure ProdAboveAVG
as
begin
declare @s float
set @s=(select sum(SalesQty*UnitPrice)from Sales.SalesOrder)/(select count(ProductID) FROM Product.Product)
select * from Product.Product where ProductID in
(select ProductID from Sales.SalesOrder where (SELECT SUM(SalesQty*UnitPrice) FROM Sales.SalesOrder group by ProductID)>=@s)
end
go

--年销售总量
go
create procedure AmountForAll
as
begin
select '年份'=DATEPART(yy,salesdate),'总额'=sum(salesqty*unitprice) from Sales.SalesOrder 
group by DATEPART(yy,salesdate)
end
go
--exec AmountForAll


--显示员工个人销售总额
go
create procedure EMPSalesmount
as
begin
select EmployeeID,'总额'=sum(SalesQty*UnitPrice) from Sales.SalesOrder group by EmployeeID
end
go
--exec EMPSalesmount


--显示员工个人年销售信息
go
create procedure EMP_yearSalesAmount
as
begin
select '员工ID'=Employeeid,'年份'=datepart(yy,SalesDate),'销售总额'=sum(salesqty*unitprice) from Sales.SalesOrder 
group by rollup(EmployeeID,datepart(yy,SalesDate))
end
go
--exec EMP_yearSalesAmount


 --显示销售总额与年销售额的对比关系
 go
create procedure AmountPerYear
as
begin
select '年份'=DATEPART(yy,salesdate),'销售总额'=sum(salesqty*unitprice) from Sales.SalesOrder 
group by DATEPART(yy,salesdate)
select '销售总额'=sum(salesqty*unitprice) from Sales.SalesOrder
end
go
--exec AmountPerYear


--员工年销售量
go
create Proc EmpAllAmount
as
begin
select EmployeeID,'销售总额'=sum(salesqty*unitprice) from Sales.SalesOrder group by employeeID
end
go
--exec EmpAllAmount

--员工销售量排名
go
create proc SalesEmpRank
as
begin
select EmployeeID,'销售额'=sum(salesqty*unitprice), '销售排名'=rank() over (order by sum(salesqty*unitprice) desc)
from Sales.SalesOrder group by employeeid
end
go
--exec SalesEmpRank

--
go
create procedure NoOrderInMonth(@Y INT,@m int)
as
begin
select a.employeeID,a.EMPLOYEENAME,A.BIRTHDATE,A.HIREDATE,A.LEFTDATE,A.DESIGNATION,A.RESIGNFLAG,A.DEPARTMENTID 
from Employee.Employee a join sALES.SalesOrder b on a.employeeid=b.employeeid 
where DATEPART(yy,salesdate)=@Y and DATEPART(mm,salesdate)=@m AND
(select sum(salesqty*unitprice) from sALES.SalesOrder where DATEPART(yy,salesdate)=@Y AND DATEPART(mm,salesdate)=@m
group by rollup(employeeid,DATEPART(mm,salesdate)))=0
end
go
--exec NoOrderInMonth 1 ,2 


--
create procedure NoOrderInYear(@Y int)
as
begin
select a.employeeID,A.EMPLOYEENAME,A.BIRTHDATE,A.HIREDATE,A.LEFTDATE,A.DESIGNATION,A.RESIGNFLAG,A.DEPARTMENTID 
from Employee.Employee a join Sales.SalesOrder b on a.employeeid=b.employeeid 
where DATEPART(yy,salesdate)=@Y and
(select sum(salesqty*unitprice) from Sales.SalesOrder where DATEPART(yy,salesdate)=@Y 
group by rollup(employeeid,DATEPART(yy,salesdate)))=0
end

--顾客对应的销售量
go
CREATE PROC CustomerAmount(@y int)
AS
BEGIN
SELECT customerID,'数额'=sum(salesqty*unitprice),'排名'=rank() over (order by sum(salesqty*unitprice) desc) 
from Sales.Customer a left outer join Sales.SalesOrder b on a.salesorderid=b.salesorderid
where DATEPART(yy,salesdate)=@y
group by a.customerid
END
go


--月份对应的销售量
go
create proc AmountPerMonth(@y int)
as
begin
select DATEPART(mm,salesdate) as '月份',sum(salesqty*unitprice) as '总额' from Sales.SalesOrder 
where DATEPART(yy,salesdate)=@y
group by DATEPART(mm,salesdate)
end
go
--exec AmountPerMonth 2

------------------------------------------
---------------------------------------------
---------------------------------------------
--演示代码：

--演示过程 1
select* from  Product.Stock 
insert Purchase.PurchaseOrder
values('P00011','Pro001',280,'2012.7.16')
select* from Purchase.PurchaseOrder


--代码部分
--当产品售出或购入时，库存必须相应地进行更新

create trigger AddP on Purchase.PurchaseOrder
for insert as
begin  
DECLARE @qty INT
SELECT @qty=QTY FROM inserted
 print @qty
update	Product.Stock set product.Stock.StkRestQty=product.Stock.StkRestQty+@qty from product.Stock
where  Stock.StkID=(select StkID from Product.Product join inserted on inserted.ProductID=Product.ProductID)
end
go
---------------------------------------------------------------------------------------------------------

--演示过程2

select* from employee.Salary
exec SalesPersonSalary
insert Purchase.PurchaseOrder
values('P00010','Pro001',280,'2012.7.16')

--代码部分
go
create proc SalesPersonSalary as
begin
With SalaryCTE(EmpId,Year,Month,Amount) 
as (
select EmployeeID,year(SalesDate),month(SalesDate),sum(SalesQty*UnitPrice)as Amount
from Sales.SalesOrder group by EmployeeID,year(SalesDate),month(SalesDate)
)
insert into Employee.Salary  select aa.EmpId,aa.Year,aa.Month,aa.Amount  from (select EmpId,Year,Month,Amount=(
case  
when Amount<5000 then Amount*0.02+2000
when Amount>=5000 and Amount<=6000 then Amount*0.05+2000
when Amount>6000 and Amount<=10000 then Amount*0.08+2000
when Amount>10000 then Amount*0.1+2000 
end)
from SalaryCTE) as aa
end
go


--演示存储过程
  --exec Monthly_Total 9
--截取某一月份的销售总额
select * from Sales.SalesOrder
go
create proc Monthly_Total(@y int)
as
begin
select '月份'=DATEPART(mm,salesdate),'月总额'=sum(salesqty*unitprice) from Sales.SalesOrder
where DATEPART(MM,salesdate)=@y group by DATEPART(mm,salesdate)
end
go
drop proc Monthly_Total
--------------------------------------------------------------------------------------------


--求指定年份的销售细节
--exec ProdAmountInYear 2014


select * from Sales.SalesOrder
go
create procedure ProdAmountInYear(@y int)
as
begin
select * from Sales.SalesOrder where DATEPART(YY,SalesDate)=@y
end
go

--drop proc Monthly_Total

-------------------------------------------------
-------------------------------------------------
------------------------------------------------
--step4
--插入数据：



insert Product.Stock values
('Stock_001','Stk001','HaiEr Road #12',123),
('Stock_002','Stk002','KeDa Road #13',456),
('Stock_003','Stk003','ZaoShanDong Road #17',789),
('Stock_004','Stk004','ShanDong Road #237',101),
('Stock_Rest','Stk005','Haier Road #134',112)

insert Product.Product values('Pro001','North','CCTV Camera','Used to Equip the CCTV system','Stk001')
insert Product.Product values('Pro002','West','DVR','Digital Video Recorder','Stk003')
insert product.Product values('Pro003','East','PTZ Camera','Pan Tilt Zoom ,Used to sweep the whole area','Stk002')
insert product.Product values('Pro004','West','Wireless Camera','Easy portable','Stk004')
insert product.Product values('Pro005','North','IP Camera','Used to Equip the CCTV system','Stk005')


Insert PURCHASE.PurchaseOrder values('P00001','Pro002',100,'2010.4.28 12:45')
Insert PURCHASE.PurchaseOrder values('P00002','Pro001',600,'2011.5.8 11:30')
Insert PURCHASE.PurchaseOrder values('P00003','Pro004',80,'2012.7.16')
Insert PURCHASE.PurchaseOrder values('P00004','Pro005',60,'2011.5.8')
Insert PURCHASE.PurchaseOrder values('P00005','Pro003',10,'2010.6.16')
Insert PURCHASE.PurchaseOrder values('P00008','Pro001',680,'2011.12.8')

insert Employee.Department values
('Dpt102','HR'),
('Dpt001','General Manger'),
('Dpt802','Marketing'),
('Dpt301','Administration')

insert Employee.Employee values('Emp201','Susan','1988.6.6','2012.5.2',null,'Manager',0,'Dpt802')
insert Employee.Employee values('Emp002','Eric','1968.3.6','1999.6.2',null,'CEO',0,'Dpt001')
insert Employee.Employee values('Emp801','Lily','1985.4.9','2013.8.2',null,'Salesman',0,'Dpt802')
insert Employee.Employee values('Emp802','Kelison','1984.7.9','2014.7.2',null,'Salesman',0,'Dpt802')
insert Employee.Employee values('Emp001','Edward','1966.6.6','1994.5.6','2013.8.1','Forme CEO',1,'Dpt001')
insert Employee.Employee values('Emp701','James','1978.12.6','2006.4.2',null,'Manager',0,'Dpt102')
insert Employee.Employee values('Emp702','Nanth','1980.7.9','2009.2.2',null,'Manager',0,'Dpt301')
insert Employee.Employee values('Emp803','lily','1990.6.6','2014.5.2',null,'Salesman',0,'Dpt802')
insert Employee.Employee values('Emp804','Machel','1986.4.6','2013.5.2',null,'Salesman',0,'Dpt802')
insert Employee.Employee values('Emp808','Max','1980.5.6','2013.5.2','2015.12.1','Salesman',2,'Dpt802')

insert Sales.SalesOrder values ('S00001',12,'2014.5.16',14.56,'Pro001','Emp803')
insert Sales.SalesOrder values('S00002',45,'2014.7.16',18.56,'Pro002','Emp801')
insert Sales.SalesOrder values('S00004',78,'2014.9.16',24.56,'Pro001','Emp803')
insert Sales.SalesOrder values('S00005',89,'2014.1.16',14.7,'Pro001','Emp803')
insert Sales.SalesOrder values('S00006',45,'2014.12.16',44.56,'Pro004','Emp804')
insert Sales.SalesOrder values('S00008',55,'2014.9.6',54.56,'Pro005','Emp802')
insert Sales.SalesOrder values('S00012',78,'2013.9.15',15.68,'Pro005','Emp804')
insert Sales.SalesOrder values('S00045',126,'2015.1.16',14.56,'Pro001','Emp803')

insert SALES.Customer values
('Cst001','Isabela',11000456,'2014.3.28','SetLegel Avenue','S00001'),
('Cst003','Harward',11000745,'2013.9.8 ','NASA Avenue','S00002'),
('Cst005','Jackson',11000886,'2012.5.8','Hawaii Avenue','S00004'),
('Cst008','Quenss',11000110,'2015.6.9 ',null,'S00005')

insert pURCHASE.Vender values('Ven001',14.21,'2014.4.6','2015.9.3',123,13.99,'No.1 Road','P00001'),
('Ven005',16.86,'2010.9.6','2014.2.3',189,15.19,'No.2 Road','P00003'),
('Ven003',75.21,'2011.9.14','2014.12.3',112,74.99,'No.3 Road','P00005'),
('Ven009',26.21,'2010.11.12','2014.11.3',146,25.99,'No.9 Road','P00004')









