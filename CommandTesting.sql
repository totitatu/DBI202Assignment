--select *
--from Employees
--where hubID = 1
--order by baseSalary desc

--SELECT * FROM dbo.employeeMonthlySalary(1,1,2024)

--SELECT * FROM dbo.orderHasNotBeenShipped(2)

--DECLARE @x INT
--EXEC revenueOfMonth 1,2024,@x OUTPUT
--SELECT @x AS TotalCostOrders 

--DECLARE @x INT
--EXEC profitOfMonth 1,2024,@x OUTPUT
--SELECT @x AS profitOfMonth

--UPDATE Employees
--SET role = 'Manager'
--WHERE empID = 4
--SELECT * FROM Hubs
--SELECT * FROM Employees

--SELECT * FROM Orders
--insert into Orders (cusID, rcvID, typeOfOrd, COD, fromAddrID, toAddrID, distance, shipperID,  rating, cost)
--values 
--(1, 2, 'Normal', 50000, 25, 29, 10.5, 1, 4, 30000)
--select * from Orders order by timeOrdered desc