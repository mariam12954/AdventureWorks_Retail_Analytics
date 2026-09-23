USE AdventureWorks2022;
GO

SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE
    (s.name = 'Sales' AND t.name IN
        ('SalesOrderHeader','SalesOrderDetail','Customer','SalesPerson',
         'SalesTerritory','Store','SpecialOffer','SpecialOfferProduct'))
    OR
    (s.name = 'Production' AND t.name IN
        ('Product','ProductSubcategory','ProductCategory'))
    OR
    (s.name = 'Person' AND t.name IN
        ('Person'))
ORDER BY s.name, t.name;
GO

SELECT
    sch.name AS SchemaName,
    tab.name AS TableName,
    col.name AS PrimaryKeyColumn,
    ic.key_ordinal
FROM sys.tables tab
JOIN sys.schemas sch ON sch.schema_id = tab.schema_id
JOIN sys.indexes i ON i.object_id = tab.object_id AND i.is_primary_key = 1
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns col ON col.object_id = ic.object_id AND col.column_id = ic.column_id
WHERE
    (sch.name + '.' + tab.name) IN
    ('Sales.SalesOrderHeader','Sales.SalesOrderDetail','Sales.Customer',
     'Sales.SalesPerson','Sales.SalesTerritory','Sales.Store',
     'Production.Product','Production.ProductSubcategory',
     'Production.ProductCategory','Person.Person')
ORDER BY sch.name, tab.name, ic.key_ordinal;
GO


SELECT
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS ParentSchema,
    OBJECT_NAME(fk.parent_object_id) AS ParentTable,
    pc.name AS ForeignKeyColumn,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS ReferencedSchema,
    OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable,
    rc.name AS ReferencedColumn
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id
JOIN sys.columns pc
    ON pc.object_id = fk.parent_object_id
   AND pc.column_id = fkc.parent_column_id
JOIN sys.columns rc
    ON rc.object_id = fk.referenced_object_id
   AND rc.column_id = fkc.referenced_column_id
WHERE
    (OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' + OBJECT_NAME(fk.parent_object_id)) IN
    ('Sales.SalesOrderHeader','Sales.SalesOrderDetail','Sales.Customer',
     'Sales.SalesPerson','Sales.SalesTerritory','Production.Product',
     'Production.ProductSubcategory','Production.ProductCategory')
ORDER BY ParentSchema, ParentTable, ForeignKeyColumn;
GO

SELECT
    COUNT(*) AS HeaderRows,
    COUNT(DISTINCT SalesOrderID) AS DistinctOrders,
    MIN(OrderDate) AS FirstOrderDate,
    MAX(OrderDate) AS LastOrderDate
FROM Sales.SalesOrderHeader;
GO

SELECT
    COUNT(*) AS DetailRows,
    COUNT(DISTINCT SalesOrderID) AS OrdersRepresented,
    COUNT(DISTINCT ProductID) AS ProductsRepresented
FROM Sales.SalesOrderDetail;
GO



SELECT
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS TotalSales,
    COUNT(DISTINCT SOH.SalesOrderID) AS TotalOrders,
    SUM(SOD.OrderQty) AS TotalQuantitySold,
    COUNT(DISTINCT SOH.CustomerID) AS TotalCustomers,
    CAST(SUM(SOD.LineTotal) / NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0)
         AS decimal(18,2)) AS AverageOrderValue
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID;
GO

SELECT
    YEAR(SOH.OrderDate) AS SalesYear,
    MONTH(SOH.OrderDate) AS SalesMonth,
    DATENAME(MONTH, SOH.OrderDate) AS MonthName,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Sales,
    COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
    COUNT(DISTINCT SOH.CustomerID) AS Customers,
    SUM(SOD.OrderQty) AS Quantity,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS decimal(18,2)) AS AOV
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
GROUP BY YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), DATENAME(MONTH, SOH.OrderDate)
ORDER BY SalesYear, SalesMonth;
GO


SELECT
    YEAR(SOH.OrderDate) AS SalesYear,
    DATEPART(QUARTER, SOH.OrderDate) AS SalesQuarter,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Sales,
    COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
    COUNT(DISTINCT SOH.CustomerID) AS Customers,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS decimal(18,2)) AS AOV
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
GROUP BY YEAR(SOH.OrderDate), DATEPART(QUARTER, SOH.OrderDate)
ORDER BY SalesYear, SalesQuarter;
GO


WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1) AS MonthStart,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1)
),
Ranked AS
(
    SELECT *,
           RANK() OVER (ORDER BY Sales DESC) AS BestRank,
           RANK() OVER (ORDER BY Sales ASC) AS WorstRank
    FROM Monthly
)
SELECT
    MonthStart,
    CAST(Sales AS decimal(18,2)) AS Sales,
    CASE WHEN BestRank = 1 THEN 'Best Period'
         WHEN WorstRank = 1 THEN 'Worst Period'
         ELSE 'Other' END AS PeriodFlag
FROM Ranked
WHERE BestRank = 1 OR WorstRank = 1
ORDER BY Sales DESC;
GO

SELECT
    YEAR(SOH.OrderDate) AS SalesYear,
    MONTH(SOH.OrderDate) AS SalesMonth,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS decimal(18,2)) AS AOV
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
GROUP BY YEAR(SOH.OrderDate), MONTH(SOH.OrderDate)
ORDER BY SalesYear, SalesMonth;
GO



WITH Yearly AS
(
    SELECT
        YEAR(SOH.OrderDate) AS SalesYear,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY YEAR(SOH.OrderDate)
),
Yoy AS
(
    SELECT *,
           LAG(Sales) OVER (ORDER BY SalesYear) AS PreviousYearSales
    FROM Yearly
)
SELECT
    SalesYear,
    CAST(Sales AS decimal(18,2)) AS Sales,
    CAST(PreviousYearSales AS decimal(18,2)) AS PreviousYearSales,
    CAST(100.0 * (Sales - PreviousYearSales) /
         NULLIF(PreviousYearSales,0) AS decimal(10,2)) AS YoYGrowthPct
FROM Yoy
ORDER BY SalesYear;
GO

-- Period contribution to total revenue
WITH PeriodSales AS
(
    SELECT
        YEAR(SOH.OrderDate) AS SalesYear,
        DATEPART(QUARTER, SOH.OrderDate) AS SalesQuarter,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY YEAR(SOH.OrderDate), DATEPART(QUARTER, SOH.OrderDate)
)
SELECT
    SalesYear,
    SalesQuarter,
    CAST(Sales AS decimal(18,2)) AS Sales,
    CAST(100.0 * Sales / SUM(Sales) OVER() AS decimal(10,2)) AS RevenueContributionPct
FROM PeriodSales
ORDER BY Sales DESC;
GO

--  Top periods and their combined contribution
WITH PeriodSales AS
(
    SELECT
        DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1) AS MonthStart,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1)
),
Ranked AS
(
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY Sales DESC) AS SalesRank
    FROM PeriodSales
)
SELECT
    COUNT(*) AS Top5Periods,
    CAST(SUM(Sales) AS decimal(18,2)) AS Top5Sales,
    CAST(100.0 * SUM(Sales) /
         (SELECT SUM(Sales) FROM PeriodSales) AS decimal(10,2)) AS Top5RevenueContributionPct
FROM Ranked
WHERE SalesRank <= 5;
GO




--  Products by revenue
SELECT TOP (20)
    P.ProductID,
    P.Name AS ProductName,
    PSC.Name AS Subcategory,
    PC.Name AS Category,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Revenue,
    SUM(SOD.OrderQty) AS QuantitySold,
    COUNT(DISTINCT SOD.SalesOrderID) AS Orders
FROM Sales.SalesOrderDetail SOD
JOIN Production.Product P
    ON SOD.ProductID = P.ProductID
LEFT JOIN Production.ProductSubcategory PSC
    ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
LEFT JOIN Production.ProductCategory PC
    ON PSC.ProductCategoryID = PC.ProductCategoryID
GROUP BY P.ProductID, P.Name, PSC.Name, PC.Name
ORDER BY Revenue DESC;
GO

--  Products by quantity
SELECT TOP (20)
    P.ProductID,
    P.Name AS ProductName,
    PSC.Name AS Subcategory,
    PC.Name AS Category,
    SUM(SOD.OrderQty) AS QuantitySold,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Revenue
FROM Sales.SalesOrderDetail SOD
JOIN Production.Product P
    ON SOD.ProductID = P.ProductID
LEFT JOIN Production.ProductSubcategory PSC
    ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
LEFT JOIN Production.ProductCategory PC
    ON PSC.ProductCategoryID = PC.ProductCategoryID
GROUP BY P.ProductID, P.Name, PSC.Name, PC.Name
ORDER BY QuantitySold DESC;
GO

--  High-value / low-quantity products
WITH ProductMetrics AS
(
    SELECT
        P.ProductID,
        P.Name AS ProductName,
        PSC.Name AS Subcategory,
        PC.Name AS Category,
        SUM(SOD.OrderQty) AS QuantitySold,
        SUM(SOD.LineTotal) AS Revenue,
        SUM(SOD.LineTotal) / NULLIF(SUM(SOD.OrderQty),0) AS RevenuePerUnit
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P ON SOD.ProductID = P.ProductID
    LEFT JOIN Production.ProductSubcategory PSC
        ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory PC
        ON PSC.ProductCategoryID = PC.ProductCategoryID
    GROUP BY P.ProductID, P.Name, PSC.Name, PC.Name
),
Thresholds AS
(
    SELECT
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Revenue)
            OVER () AS Revenue75,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY QuantitySold)
            OVER () AS Quantity25
    FROM ProductMetrics
)
SELECT DISTINCT
    PM.*,
    'High Revenue / Low Quantity' AS ProductPattern
FROM ProductMetrics PM
CROSS JOIN Thresholds T
WHERE PM.Revenue >= T.Revenue75
  AND PM.QuantitySold <= T.Quantity25
ORDER BY PM.Revenue DESC;
GO

--  High-quantity / low-value products
WITH ProductMetrics AS
(
    SELECT
        P.ProductID,
        P.Name AS ProductName,
        PSC.Name AS Subcategory,
        PC.Name AS Category,
        SUM(SOD.OrderQty) AS QuantitySold,
        SUM(SOD.LineTotal) AS Revenue,
        SUM(SOD.LineTotal) / NULLIF(SUM(SOD.OrderQty),0) AS RevenuePerUnit
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P ON SOD.ProductID = P.ProductID
    LEFT JOIN Production.ProductSubcategory PSC
        ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory PC
        ON PSC.ProductCategoryID = PC.ProductCategoryID
    GROUP BY P.ProductID, P.Name, PSC.Name, PC.Name
),
Thresholds AS
(
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Revenue)
            OVER () AS Revenue25,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY QuantitySold)
            OVER () AS Quantity75
    FROM ProductMetrics
)
SELECT DISTINCT
    PM.*,
    'High Quantity / Low Revenue' AS ProductPattern
FROM ProductMetrics PM
CROSS JOIN Thresholds T
WHERE PM.Revenue <= T.Revenue25
  AND PM.QuantitySold >= T.Quantity75
ORDER BY PM.QuantitySold DESC;
GO

--  Products underperforming relative to their category
WITH ProductRevenue AS
(
    SELECT
        P.ProductID,
        P.Name AS ProductName,
        PC.Name AS Category,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P ON SOD.ProductID = P.ProductID
    LEFT JOIN Production.ProductSubcategory PSC
        ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory PC
        ON PSC.ProductCategoryID = PC.ProductCategoryID
    GROUP BY P.ProductID, P.Name, PC.Name
),
CategoryStats AS
(
    SELECT
        Category,
        AVG(Revenue) AS AvgProductRevenue
    FROM ProductRevenue
    GROUP BY Category
)
SELECT
    PR.ProductID,
    PR.ProductName,
    PR.Category,
    CAST(PR.Revenue AS decimal(18,2)) AS Revenue,
    CAST(CS.AvgProductRevenue AS decimal(18,2)) AS CategoryAvgProductRevenue,
    CAST(100.0 * PR.Revenue / NULLIF(CS.AvgProductRevenue,0)
         AS decimal(10,2)) AS RevenueVsCategoryAvgPct
FROM ProductRevenue PR
JOIN CategoryStats CS ON PR.Category = CS.Category
WHERE PR.Revenue < CS.AvgProductRevenue
ORDER BY RevenueVsCategoryAvgPct ASC;
GO

--  Category revenue and share
WITH CategoryRevenue AS
(
    SELECT
        PC.ProductCategoryID,
        PC.Name AS Category,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P ON SOD.ProductID = P.ProductID
    LEFT JOIN Production.ProductSubcategory PSC
        ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory PC
        ON PSC.ProductCategoryID = PC.ProductCategoryID
    GROUP BY PC.ProductCategoryID, PC.Name
)
SELECT
    Category,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    CAST(100.0 * Revenue / SUM(Revenue) OVER()
         AS decimal(10,2)) AS RevenueSharePct
FROM CategoryRevenue
ORDER BY Revenue DESC;
GO

--  Subcategory contribution within category
WITH SubcategoryRevenue AS
(
    SELECT
        PC.Name AS Category,
        PSC.Name AS Subcategory,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P ON SOD.ProductID = P.ProductID
    LEFT JOIN Production.ProductSubcategory PSC
        ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory PC
        ON PSC.ProductCategoryID = PC.ProductCategoryID
    GROUP BY PC.Name, PSC.Name
)
SELECT
    Category,
    Subcategory,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    CAST(100.0 * Revenue /
         SUM(Revenue) OVER (PARTITION BY Category) AS decimal(10,2))
         AS CategoryRevenueSharePct,
    RANK() OVER (PARTITION BY Category ORDER BY Revenue DESC) AS SubcategoryRank
FROM SubcategoryRevenue
ORDER BY Category, Revenue DESC;
GO

-- Product 80/20 style analysis
WITH ProductRevenue AS
(
    SELECT
        P.ProductID,
        P.Name AS ProductName,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P ON SOD.ProductID = P.ProductID
    GROUP BY P.ProductID, P.Name
),
Ranked AS
(
    SELECT
        *,
        SUM(Revenue) OVER (ORDER BY Revenue DESC
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CumulativeRevenue,
        SUM(Revenue) OVER () AS TotalRevenue,
        ROW_NUMBER() OVER (ORDER BY Revenue DESC) AS ProductRank,
        COUNT(*) OVER () AS ProductCount
    FROM ProductRevenue
)
SELECT
    ProductRank,
    ProductCount,
    ProductID,
    ProductName,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    CAST(100.0 * CumulativeRevenue / TotalRevenue AS decimal(10,2))
        AS CumulativeRevenuePct,
    CAST(100.0 * ProductRank / ProductCount AS decimal(10,2))
        AS ProductSharePct
FROM Ranked
WHERE 100.0 * CumulativeRevenue / TotalRevenue <= 85
   OR ProductRank <= CEILING(ProductCount * 0.20)
ORDER BY ProductRank;
GO

--  Product management priority list
WITH ProductMetrics AS
(
    SELECT
        P.ProductID,
        P.Name AS ProductName,
        PC.Name AS Category,
        SUM(SOD.OrderQty) AS QuantitySold,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P ON SOD.ProductID = P.ProductID
    LEFT JOIN Production.ProductSubcategory PSC
        ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory PC
        ON PSC.ProductCategoryID = PC.ProductCategoryID
    GROUP BY P.ProductID, P.Name, PC.Name
),
Ranked AS
(
    SELECT *,
           RANK() OVER (ORDER BY Revenue DESC) AS RevenueRank,
           RANK() OVER (ORDER BY QuantitySold DESC) AS QuantityRank
    FROM ProductMetrics
)
SELECT TOP (30)
    *,
    CASE
        WHEN RevenueRank <= 10 AND QuantityRank <= 10
            THEN 'Protect / Prioritize'
        WHEN RevenueRank <= 10
            THEN 'High Revenue - Review Volume'
        WHEN QuantityRank <= 10
            THEN 'High Volume - Review Value'
        ELSE 'Monitor'
    END AS ManagementPriority
FROM Ranked
ORDER BY RevenueRank;
GO




--  Number of unique purchasing customers
SELECT COUNT(DISTINCT CustomerID) AS UniquePurchasingCustomers
FROM Sales.SalesOrderHeader;
GO

--  Highest-value customers
SELECT TOP (25)
    SOH.CustomerID,
    CASE
        WHEN P.BusinessEntityID IS NOT NULL
            THEN CONCAT(P.FirstName, ' ', P.LastName)
        WHEN ST.Name IS NOT NULL
            THEN ST.Name
        ELSE CONCAT('Customer ', SOH.CustomerID)
    END AS CustomerName,
    COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
    SUM(SOD.OrderQty) AS QuantityPurchased,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Revenue,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS decimal(18,2)) AS AOV
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
LEFT JOIN Sales.Customer C
    ON SOH.CustomerID = C.CustomerID
LEFT JOIN Person.Person P
    ON C.PersonID = P.BusinessEntityID
LEFT JOIN Sales.Store ST
    ON C.StoreID = ST.BusinessEntityID
GROUP BY SOH.CustomerID,
         CASE
             WHEN P.BusinessEntityID IS NOT NULL
                 THEN CONCAT(P.FirstName, ' ', P.LastName)
             WHEN ST.Name IS NOT NULL
                 THEN ST.Name
             ELSE CONCAT('Customer ', SOH.CustomerID)
         END
ORDER BY Revenue DESC;
GO

--  Customer average spending and variation
WITH CustomerRevenue AS
(
    SELECT
        CustomerID,
        SUM(SOD.LineTotal) AS Revenue,
        COUNT(DISTINCT SOH.SalesOrderID) AS Orders
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY CustomerID
)
SELECT
    COUNT(*) AS Customers,
    CAST(AVG(Revenue) AS decimal(18,2)) AS AverageCustomerSpending,
    CAST(MIN(Revenue) AS decimal(18,2)) AS MinimumCustomerSpending,
    CAST(MAX(Revenue) AS decimal(18,2)) AS MaximumCustomerSpending,
    CAST(STDEV(Revenue) AS decimal(18,2)) AS SpendingStdDev,
    CAST(AVG(Orders) AS decimal(10,2)) AS AverageOrdersPerCustomer
FROM CustomerRevenue;
GO

--  Customer purchase frequency
SELECT
    OrderCount,
    COUNT(*) AS NumberOfCustomers
FROM
(
    SELECT
        CustomerID,
        COUNT(DISTINCT SalesOrderID) AS OrderCount
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
) X
GROUP BY OrderCount
ORDER BY OrderCount;
GO

--  Customers with most orders
SELECT TOP (25)
    SOH.CustomerID,
    COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Revenue,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS decimal(18,2)) AS AOV
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
GROUP BY SOH.CustomerID
ORDER BY Orders DESC, Revenue DESC;
GO

--  Revenue ranking vs frequency ranking
WITH CustomerMetrics AS
(
    SELECT
        SOH.CustomerID,
        COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY SOH.CustomerID
)
SELECT TOP (50)
    *,
    RANK() OVER (ORDER BY Revenue DESC) AS RevenueRank,
    RANK() OVER (ORDER BY Orders DESC) AS FrequencyRank,
    RevenueRankDifference = 
        RANK() OVER (ORDER BY Orders DESC) -
        RANK() OVER (ORDER BY Revenue DESC)
FROM CustomerMetrics
ORDER BY Revenue DESC;
GO

--  Revenue from top 10% and 20% of customers
WITH CustomerRevenue AS
(
    SELECT
        CustomerID,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY CustomerID
),
Ranked AS
(
    SELECT *,
           NTILE(10) OVER (ORDER BY Revenue DESC) AS Decile,
           SUM(Revenue) OVER () AS TotalRevenue
    FROM CustomerRevenue
)
SELECT
    CAST(100.0 * SUM(CASE WHEN Decile = 1 THEN Revenue ELSE 0 END)
         / MAX(TotalRevenue) AS decimal(10,2)) AS Top10PctCustomerRevenueShare,
    CAST(100.0 * SUM(CASE WHEN Decile <= 2 THEN Revenue ELSE 0 END)
         / MAX(TotalRevenue) AS decimal(10,2)) AS Top20PctCustomerRevenueShare
FROM Ranked;
GO

--  Frequent but low-spending customers
WITH CustomerMetrics AS
(
    SELECT
        CustomerID,
        COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
        SUM(SOD.LineTotal) AS Revenue,
        SUM(SOD.LineTotal) / NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS AOV
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY CustomerID
),
T AS
(
    SELECT
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Orders) OVER() AS Orders75,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Revenue) OVER() AS Revenue25
    FROM CustomerMetrics
)
SELECT DISTINCT
    CM.*,
    'Frequent / Low Value' AS CustomerPattern
FROM CustomerMetrics CM
CROSS JOIN T
WHERE CM.Orders >= T.Orders75
  AND CM.Revenue <= T.Revenue25
ORDER BY CM.Orders DESC, CM.Revenue ASC;
GO

--  Few purchases but very high spending
WITH CustomerMetrics AS
(
    SELECT
        CustomerID,
        COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
        SUM(SOD.LineTotal) AS Revenue,
        SUM(SOD.LineTotal) / NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS AOV
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY CustomerID
),
T AS
(
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Orders) OVER() AS Orders25,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Revenue) OVER() AS Revenue75
    FROM CustomerMetrics
)
SELECT DISTINCT
    CM.*,
    'Low Frequency / High Value' AS CustomerPattern
FROM CustomerMetrics CM
CROSS JOIN T
WHERE CM.Orders <= T.Orders25
  AND CM.Revenue >= T.Revenue75
ORDER BY CM.Revenue DESC;
GO




IF OBJECT_ID('tempdb..#CustomerMetrics') IS NOT NULL
    DROP TABLE #CustomerMetrics;

SELECT
    SOH.CustomerID,
    MAX(CAST(SOH.OrderDate AS date)) AS LastPurchaseDate,
    DATEDIFF
    (
        DAY,
        MAX(CAST(SOH.OrderDate AS date)),
        (SELECT MAX(CAST(OrderDate AS date)) FROM Sales.SalesOrderHeader)
    ) AS RecencyDays,
    COUNT(DISTINCT SOH.SalesOrderID) AS FrequencyOrders,
    SUM(SOD.LineTotal) AS MonetaryRevenue,
    SUM(SOD.OrderQty) AS TotalQuantity,
    SUM(SOD.LineTotal) /
        NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS AOV
INTO #CustomerMetrics
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
GROUP BY SOH.CustomerID;
GO

-- RFM quintile scores
IF OBJECT_ID('tempdb..#RFM') IS NOT NULL
    DROP TABLE #RFM;

SELECT
    *,
    6 - NTILE(5) OVER (ORDER BY RecencyDays ASC) AS RecencyScore,
    NTILE(5) OVER (ORDER BY FrequencyOrders ASC) AS FrequencyScore,
    NTILE(5) OVER (ORDER BY MonetaryRevenue ASC) AS MonetaryScore
INTO #RFM
FROM #CustomerMetrics;
GO

--  RFM segments
SELECT
    CustomerID,
    LastPurchaseDate,
    RecencyDays,
    FrequencyOrders,
    CAST(MonetaryRevenue AS decimal(18,2)) AS MonetaryRevenue,
    CAST(AOV AS decimal(18,2)) AS AOV,
    RecencyScore,
    FrequencyScore,
    MonetaryScore,
    (RecencyScore + FrequencyScore + MonetaryScore) AS RFMTotalScore,
    CASE
        WHEN RecencyScore >= 4 AND FrequencyScore >= 4 AND MonetaryScore >= 4
            THEN 'Champions'
        WHEN RecencyScore >= 3 AND FrequencyScore >= 3 AND MonetaryScore >= 3
            THEN 'Loyal / High Value'
        WHEN RecencyScore >= 4 AND FrequencyScore <= 2
            THEN 'Recent / Potential'
        WHEN RecencyScore <= 2 AND MonetaryScore >= 4
            THEN 'At Risk - High Value'
        WHEN RecencyScore <= 2 AND FrequencyScore <= 2 AND MonetaryScore <= 2
            THEN 'Lost'
        ELSE 'Needs Attention'
    END AS CustomerSegment
FROM #RFM
ORDER BY RFMTotalScore DESC, MonetaryRevenue DESC;
GO

--  Segment profile: customers, share, revenue, revenue share
WITH Segments AS
(
    SELECT
        *,
        CASE
            WHEN RecencyScore >= 4 AND FrequencyScore >= 4 AND MonetaryScore >= 4
                THEN 'Champions'
            WHEN RecencyScore >= 3 AND FrequencyScore >= 3 AND MonetaryScore >= 3
                THEN 'Loyal / High Value'
            WHEN RecencyScore >= 4 AND FrequencyScore <= 2
                THEN 'Recent / Potential'
            WHEN RecencyScore <= 2 AND MonetaryScore >= 4
                THEN 'At Risk - High Value'
            WHEN RecencyScore <= 2 AND FrequencyScore <= 2 AND MonetaryScore <= 2
                THEN 'Lost'
            ELSE 'Needs Attention'
        END AS CustomerSegment
    FROM #RFM
)
SELECT
    CustomerSegment,
    COUNT(*) AS Customers,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER()
         AS decimal(10,2)) AS CustomerBaseSharePct,
    CAST(SUM(MonetaryRevenue) AS decimal(18,2)) AS Revenue,
    CAST(100.0 * SUM(MonetaryRevenue) / SUM(SUM(MonetaryRevenue)) OVER()
         AS decimal(10,2)) AS RevenueSharePct,
    CAST(AVG(FrequencyOrders) AS decimal(10,2)) AS AvgOrders,
    CAST(AVG(AOV) AS decimal(18,2)) AS AvgAOV,
    CAST(AVG(RecencyDays) AS decimal(10,2)) AS AvgRecencyDays,
    CAST(AVG(MonetaryRevenue) AS decimal(18,2)) AS AvgCustomerRevenue
FROM Segments
GROUP BY CustomerSegment
ORDER BY Revenue DESC;
GO

--  Recommended business action per segment
WITH Segments AS
(
    SELECT
        *,
        CASE
            WHEN RecencyScore >= 4 AND FrequencyScore >= 4 AND MonetaryScore >= 4
                THEN 'Champions'
            WHEN RecencyScore >= 3 AND FrequencyScore >= 3 AND MonetaryScore >= 3
                THEN 'Loyal / High Value'
            WHEN RecencyScore >= 4 AND FrequencyScore <= 2
                THEN 'Recent / Potential'
            WHEN RecencyScore <= 2 AND MonetaryScore >= 4
                THEN 'At Risk - High Value'
            WHEN RecencyScore <= 2 AND FrequencyScore <= 2 AND MonetaryScore <= 2
                THEN 'Lost'
            ELSE 'Needs Attention'
        END AS CustomerSegment
    FROM #RFM
)
SELECT
    CustomerSegment,
    CASE CustomerSegment
        WHEN 'Champions'
            THEN 'VIP loyalty, early access and cross-sell'
        WHEN 'Loyal / High Value'
            THEN 'Loyalty rewards and personalized upsell'
        WHEN 'Recent / Potential'
            THEN 'Second-purchase campaign and cross-sell'
        WHEN 'At Risk - High Value'
            THEN 'Win-back campaign and personalized retention offer'
        WHEN 'Lost'
            THEN 'Low-cost reactivation test; avoid high-cost incentives'
        ELSE 'Targeted offer based on purchase behavior'
    END AS RecommendedAction
FROM (SELECT DISTINCT CustomerSegment FROM Segments) S
ORDER BY CustomerSegment;
GO




--  Territory sales
SELECT
    ST.TerritoryID,
    ST.Name AS Territory,
    ST.CountryRegionCode,
    ST.[Group] AS RegionGroup,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Sales,
    COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
    COUNT(DISTINCT SOH.CustomerID) AS Customers,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS decimal(18,2)) AS AOV
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
JOIN Sales.SalesTerritory ST
    ON SOH.TerritoryID = ST.TerritoryID
GROUP BY ST.TerritoryID, ST.Name, ST.CountryRegionCode, ST.[Group]
ORDER BY Sales DESC;
GO

--  Territory customer counts
SELECT
    ST.TerritoryID,
    ST.Name AS Territory,
    COUNT(DISTINCT SOH.CustomerID) AS Customers,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Sales
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
JOIN Sales.SalesTerritory ST
    ON SOH.TerritoryID = ST.TerritoryID
GROUP BY ST.TerritoryID, ST.Name
ORDER BY Customers DESC;
GO

--  Territory growth YoY
WITH TerritoryYear AS
(
    SELECT
        ST.TerritoryID,
        ST.Name AS Territory,
        YEAR(SOH.OrderDate) AS SalesYear,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    JOIN Sales.SalesTerritory ST
        ON SOH.TerritoryID = ST.TerritoryID
    GROUP BY ST.TerritoryID, ST.Name, YEAR(SOH.OrderDate)
),
Growth AS
(
    SELECT *,
           LAG(Sales) OVER(PARTITION BY TerritoryID ORDER BY SalesYear) AS PreviousYearSales
    FROM TerritoryYear
)
SELECT
    TerritoryID,
    Territory,
    SalesYear,
    CAST(Sales AS decimal(18,2)) AS Sales,
    CAST(PreviousYearSales AS decimal(18,2)) AS PreviousYearSales,
    CAST(100.0 * (Sales - PreviousYearSales) /
         NULLIF(PreviousYearSales,0) AS decimal(10,2)) AS YoYGrowthPct
FROM Growth
ORDER BY SalesYear, YoYGrowthPct DESC;
GO

--  Territories above/below average sales
WITH TerritorySales AS
(
    SELECT
        ST.TerritoryID,
        ST.Name AS Territory,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    JOIN Sales.SalesTerritory ST
        ON SOH.TerritoryID = ST.TerritoryID
    GROUP BY ST.TerritoryID, ST.Name
)
SELECT
    TerritoryID,
    Territory,
    CAST(Sales AS decimal(18,2)) AS Sales,
    CAST(AVG(Sales) OVER() AS decimal(18,2)) AS AverageTerritorySales,
    CASE
        WHEN Sales >= AVG(Sales) OVER() THEN 'Above Average'
        ELSE 'Below Average'
    END AS PerformanceFlag,
    CAST(100.0 * (Sales - AVG(Sales) OVER()) /
         NULLIF(AVG(Sales) OVER(),0) AS decimal(10,2)) AS VsAveragePct
FROM TerritorySales
ORDER BY Sales DESC;
GO

--  High customers / low sales territories
WITH TerritoryMetrics AS
(
    SELECT
        ST.TerritoryID,
        ST.Name AS Territory,
        COUNT(DISTINCT SOH.CustomerID) AS Customers,
        SUM(SOD.LineTotal) AS Sales,
        SUM(SOD.LineTotal) / NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS AOV
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    JOIN Sales.SalesTerritory ST
        ON SOH.TerritoryID = ST.TerritoryID
    GROUP BY ST.TerritoryID, ST.Name
),
Thresholds AS
(
    SELECT
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Customers) OVER() AS Customers75,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Sales) OVER() AS Sales25
    FROM TerritoryMetrics
)
SELECT DISTINCT
    TM.*,
    'High Customer Count / Low Sales' AS TerritoryPattern
FROM TerritoryMetrics TM
CROSS JOIN Thresholds T
WHERE TM.Customers >= T.Customers75
  AND TM.Sales <= T.Sales25
ORDER BY TM.Customers DESC;
GO

--  Few customers / disproportionately high customer value
WITH TerritoryMetrics AS
(
    SELECT
        ST.TerritoryID,
        ST.Name AS Territory,
        COUNT(DISTINCT SOH.CustomerID) AS Customers,
        SUM(SOD.LineTotal) AS Sales,
        SUM(SOD.LineTotal) / NULLIF(COUNT(DISTINCT SOH.CustomerID),0) AS RevenuePerCustomer
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    JOIN Sales.SalesTerritory ST
        ON SOH.TerritoryID = ST.TerritoryID
    GROUP BY ST.TerritoryID, ST.Name
)
SELECT
    *,
    CAST(RevenuePerCustomer AS decimal(18,2)) AS RevenuePerCustomerValue
FROM TerritoryMetrics
ORDER BY RevenuePerCustomer DESC;
GO




--  Salesperson KPIs
SELECT
    SP.BusinessEntityID AS SalespersonID,
    CONCAT(P.FirstName, ' ', P.LastName) AS SalespersonName,
    ST.Name AS Territory,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Sales,
    COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
    COUNT(DISTINCT SOH.CustomerID) AS Customers,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS decimal(18,2)) AS AOV,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.CustomerID),0) AS decimal(18,2)) AS RevenuePerCustomer
FROM Sales.SalesPerson SP
JOIN Person.Person P
    ON SP.BusinessEntityID = P.BusinessEntityID
LEFT JOIN Sales.SalesOrderHeader SOH
    ON SP.BusinessEntityID = SOH.SalesPersonID
LEFT JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
LEFT JOIN Sales.SalesTerritory ST
    ON SP.TerritoryID = ST.TerritoryID
GROUP BY SP.BusinessEntityID, P.FirstName, P.LastName, ST.Name
ORDER BY Sales DESC;
GO

--  Salesperson performance vs company averages
WITH SalespersonMetrics AS
(
    SELECT
        SP.BusinessEntityID AS SalespersonID,
        CONCAT(P.FirstName, ' ', P.LastName) AS SalespersonName,
        SUM(SOD.LineTotal) AS Sales,
        COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
        COUNT(DISTINCT SOH.CustomerID) AS Customers,
        SUM(SOD.LineTotal) / NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS AOV,
        SUM(SOD.LineTotal) / NULLIF(COUNT(DISTINCT SOH.CustomerID),0) AS RevenuePerCustomer
    FROM Sales.SalesPerson SP
    JOIN Person.Person P
        ON SP.BusinessEntityID = P.BusinessEntityID
    JOIN Sales.SalesOrderHeader SOH
        ON SP.BusinessEntityID = SOH.SalesPersonID
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY SP.BusinessEntityID, P.FirstName, P.LastName
)
SELECT
    *,
    CAST(AVG(AOV) OVER() AS decimal(18,2)) AS CompanyAverageSalespersonAOV,
    CAST(AVG(RevenuePerCustomer) OVER() AS decimal(18,2))
        AS CompanyAverageSalespersonRevenuePerCustomer,
    CAST(100.0 * (AOV - AVG(AOV) OVER()) /
         NULLIF(AVG(AOV) OVER(),0) AS decimal(10,2)) AS AOVVsSalespersonAvgPct,
    CAST(100.0 * (RevenuePerCustomer - AVG(RevenuePerCustomer) OVER()) /
         NULLIF(AVG(RevenuePerCustomer) OVER(),0) AS decimal(10,2))
         AS RevenuePerCustomerVsAvgPct
FROM SalespersonMetrics
ORDER BY RevenuePerCustomerVsAvgPct DESC;
GO

--  Salesperson customer concentration risk
WITH CustomerSales AS
(
    SELECT
        SOH.SalesPersonID,
        SOH.CustomerID,
        SUM(SOD.LineTotal) AS CustomerRevenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    WHERE SOH.SalesPersonID IS NOT NULL
    GROUP BY SOH.SalesPersonID, SOH.CustomerID
),
Ranked AS
(
    SELECT *,
           ROW_NUMBER() OVER
               (PARTITION BY SalesPersonID ORDER BY CustomerRevenue DESC) AS CustomerRank,
           SUM(CustomerRevenue) OVER
               (PARTITION BY SalesPersonID) AS SalespersonRevenue
    FROM CustomerSales
)
SELECT
    SalesPersonID,
    MAX(SalespersonRevenue) AS SalespersonRevenue,
    SUM(CASE WHEN CustomerRank <= 5 THEN CustomerRevenue ELSE 0 END) AS Top5CustomerRevenue,
    CAST(100.0 *
         SUM(CASE WHEN CustomerRank <= 5 THEN CustomerRevenue ELSE 0 END) /
         MAX(SalespersonRevenue) AS decimal(10,2)) AS Top5CustomerConcentrationPct
FROM Ranked
GROUP BY SalesPersonID
ORDER BY Top5CustomerConcentrationPct DESC;
GO

--  Salesperson yearly trend
WITH SalespersonYear AS
(
    SELECT
        SP.BusinessEntityID AS SalespersonID,
        CONCAT(P.FirstName, ' ', P.LastName) AS SalespersonName,
        YEAR(SOH.OrderDate) AS SalesYear,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesPerson SP
    JOIN Person.Person P
        ON SP.BusinessEntityID = P.BusinessEntityID
    JOIN Sales.SalesOrderHeader SOH
        ON SP.BusinessEntityID = SOH.SalesPersonID
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY SP.BusinessEntityID, P.FirstName, P.LastName, YEAR(SOH.OrderDate)
),
Growth AS
(
    SELECT *,
           LAG(Sales) OVER(PARTITION BY SalespersonID ORDER BY SalesYear)
               AS PreviousYearSales
    FROM SalespersonYear
)
SELECT
    SalespersonID,
    SalespersonName,
    SalesYear,
    CAST(Sales AS decimal(18,2)) AS Sales,
    CAST(PreviousYearSales AS decimal(18,2)) AS PreviousYearSales,
    CAST(100.0 * (Sales - PreviousYearSales) /
         NULLIF(PreviousYearSales,0) AS decimal(10,2)) AS YoYGrowthPct
FROM Growth
ORDER BY SalespersonName, SalesYear;
GO






--  Year / quarter / month
SELECT
    YEAR(SOH.OrderDate) AS SalesYear,
    DATEPART(QUARTER, SOH.OrderDate) AS SalesQuarter,
    MONTH(SOH.OrderDate) AS SalesMonth,
    DATENAME(MONTH, SOH.OrderDate) AS MonthName,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Sales,
    COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
    COUNT(DISTINCT SOH.CustomerID) AS Customers
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
GROUP BY
    YEAR(SOH.OrderDate),
    DATEPART(QUARTER, SOH.OrderDate),
    MONTH(SOH.OrderDate),
    DATENAME(MONTH, SOH.OrderDate)
ORDER BY SalesYear, SalesMonth;
GO

--  Month-over-month growth
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1) AS MonthStart,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1)
),
M AS
(
    SELECT *,
           LAG(Sales) OVER(ORDER BY MonthStart) AS PreviousMonthSales
    FROM Monthly
)
SELECT
    MonthStart,
    CAST(Sales AS decimal(18,2)) AS Sales,
    CAST(PreviousMonthSales AS decimal(18,2)) AS PreviousMonthSales,
    CAST(100.0 * (Sales - PreviousMonthSales) /
         NULLIF(PreviousMonthSales,0) AS decimal(10,2)) AS MoMGrowthPct
FROM M
ORDER BY MonthStart;
GO

--  Running total
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1) AS MonthStart,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1)
)
SELECT
    MonthStart,
    CAST(Sales AS decimal(18,2)) AS MonthlySales,
    CAST(SUM(Sales) OVER
        (ORDER BY MonthStart ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        AS decimal(18,2)) AS RunningSales
FROM Monthly
ORDER BY MonthStart;
GO

--  Rolling 3-month average
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1) AS MonthStart,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1)
)
SELECT
    MonthStart,
    CAST(Sales AS decimal(18,2)) AS MonthlySales,
    CAST(AVG(Sales) OVER
        (ORDER BY MonthStart ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
        AS decimal(18,2)) AS Rolling3MonthAverage
FROM Monthly
ORDER BY MonthStart;
GO

--  Seasonality: average monthly revenue across observed years
WITH Monthly AS
(
    SELECT
        MONTH(SOH.OrderDate) AS MonthNumber,
        DATENAME(MONTH, SOH.OrderDate) AS MonthName,
        YEAR(SOH.OrderDate) AS SalesYear,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY MONTH(SOH.OrderDate), DATENAME(MONTH, SOH.OrderDate), YEAR(SOH.OrderDate)
)
SELECT
    MonthNumber,
    MonthName,
    CAST(AVG(Sales) AS decimal(18,2)) AS AverageMonthlySalesAcrossYears,
    CAST(MIN(Sales) AS decimal(18,2)) AS MinimumObservedSales,
    CAST(MAX(Sales) AS decimal(18,2)) AS MaximumObservedSales
FROM Monthly
GROUP BY MonthNumber, MonthName
ORDER BY MonthNumber;
GO




--  Top customers and percentage contribution
WITH CustomerSales AS
(
    SELECT
        SOH.CustomerID,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY SOH.CustomerID
)
SELECT TOP (50)
    CustomerID,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    CAST(100.0 * Revenue / SUM(Revenue) OVER()
         AS decimal(10,2)) AS RevenueContributionPct,
    RANK() OVER(ORDER BY Revenue DESC) AS CustomerRank
FROM CustomerSales
ORDER BY Revenue DESC;
GO

--  Customer ranking within territory
WITH CustomerTerritorySales AS
(
    SELECT
        SOH.TerritoryID,
        ST.Name AS Territory,
        SOH.CustomerID,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    JOIN Sales.SalesTerritory ST
        ON SOH.TerritoryID = ST.TerritoryID
    GROUP BY SOH.TerritoryID, ST.Name, SOH.CustomerID
)
SELECT
    TerritoryID,
    Territory,
    CustomerID,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    RANK() OVER(PARTITION BY TerritoryID ORDER BY Revenue DESC) AS CustomerRankWithinTerritory
FROM CustomerTerritorySales
ORDER BY Territory, CustomerRankWithinTerritory;
GO

--  Product ranking within category
WITH ProductCategorySales AS
(
    SELECT
        PC.ProductCategoryID,
        PC.Name AS Category,
        P.ProductID,
        P.Name AS ProductName,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P
        ON SOD.ProductID = P.ProductID
    LEFT JOIN Production.ProductSubcategory PSC
        ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory PC
        ON PSC.ProductCategoryID = PC.ProductCategoryID
    GROUP BY PC.ProductCategoryID, PC.Name, P.ProductID, P.Name
)
SELECT
    Category,
    ProductID,
    ProductName,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    RANK() OVER(PARTITION BY ProductCategoryID ORDER BY Revenue DESC)
        AS ProductRankWithinCategory
FROM ProductCategorySales
ORDER BY Category, ProductRankWithinCategory;
GO

--  Running sales by month
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1) AS MonthStart,
        SUM(SOD.LineTotal) AS Sales
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY DATEFROMPARTS(YEAR(SOH.OrderDate), MONTH(SOH.OrderDate), 1)
)
SELECT
    MonthStart,
    CAST(Sales AS decimal(18,2)) AS Sales,
    CAST(SUM(Sales) OVER(ORDER BY MonthStart) AS decimal(18,2)) AS RunningSales
FROM Monthly
ORDER BY MonthStart;
GO

--  Product percentage contribution
WITH ProductSales AS
(
    SELECT
        P.ProductID,
        P.Name AS ProductName,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P ON SOD.ProductID = P.ProductID
    GROUP BY P.ProductID, P.Name
)
SELECT
    ProductID,
    ProductName,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    CAST(100.0 * Revenue / SUM(Revenue) OVER()
         AS decimal(10,2)) AS ProductContributionPct
FROM ProductSales
ORDER BY Revenue DESC;
GO

--  Category percentage contribution
WITH CategorySales AS
(
    SELECT
        PC.ProductCategoryID,
        PC.Name AS Category,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P ON SOD.ProductID = P.ProductID
    LEFT JOIN Production.ProductSubcategory PSC
        ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory PC
        ON PSC.ProductCategoryID = PC.ProductCategoryID
    GROUP BY PC.ProductCategoryID, PC.Name
)
SELECT
    Category,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    CAST(100.0 * Revenue / SUM(Revenue) OVER()
         AS decimal(10,2)) AS CategoryContributionPct
FROM CategorySales
ORDER BY Revenue DESC;
GO

--  Customer percentage contribution
WITH CustomerSales AS
(
    SELECT
        CustomerID,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY CustomerID
)
SELECT
    CustomerID,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    CAST(100.0 * Revenue / SUM(Revenue) OVER()
         AS decimal(10,2)) AS CustomerContributionPct
FROM CustomerSales
ORDER BY Revenue DESC;
GO

--  Territory sales vs overall average territory sales
WITH TerritorySales AS
(
    SELECT
        ST.TerritoryID,
        ST.Name AS Territory,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    JOIN Sales.SalesTerritory ST
        ON SOH.TerritoryID = ST.TerritoryID
    GROUP BY ST.TerritoryID, ST.Name
)
SELECT
    TerritoryID,
    Territory,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    CAST(AVG(Revenue) OVER() AS decimal(18,2)) AS AverageTerritoryRevenue,
    CASE WHEN Revenue >= AVG(Revenue) OVER()
         THEN 'Above Average' ELSE 'Below Average' END AS PerformanceFlag
FROM TerritorySales
ORDER BY Revenue DESC;
GO

--  Above-average customers
WITH CustomerSales AS
(
    SELECT
        CustomerID,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY CustomerID
)
SELECT
    CustomerID,
    CAST(Revenue AS decimal(18,2)) AS Revenue,
    CAST(AVG(Revenue) OVER() AS decimal(18,2)) AS AverageCustomerRevenue,
    CAST(100.0 * (Revenue - AVG(Revenue) OVER()) /
         NULLIF(AVG(Revenue) OVER(),0) AS decimal(10,2)) AS VsAveragePct
FROM CustomerSales
WHERE Revenue > (SELECT AVG(Revenue) FROM CustomerSales)
ORDER BY Revenue DESC;
GO

--  Repeat customers vs one-time buyers
WITH CustomerOrders AS
(
    SELECT
        SOH.CustomerID,
        COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY SOH.CustomerID
)
SELECT
    CASE WHEN Orders > 1 THEN 'Repeat Buyer' ELSE 'One-Time Buyer' END AS BuyerType,
    COUNT(*) AS Customers,
    CAST(SUM(Revenue) AS decimal(18,2)) AS Revenue,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER()
         AS decimal(10,2)) AS CustomerSharePct,
    CAST(100.0 * SUM(Revenue) / SUM(SUM(Revenue)) OVER()
         AS decimal(10,2)) AS RevenueSharePct
FROM CustomerOrders
GROUP BY CASE WHEN Orders > 1 THEN 'Repeat Buyer' ELSE 'One-Time Buyer' END
ORDER BY Revenue DESC;
GO

--  High-value, low-frequency customers
WITH CustomerMetrics AS
(
    SELECT
        CustomerID,
        COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY CustomerID
),
Thresholds AS
(
    SELECT
        MAX(Orders25) AS Orders25,
        MAX(Revenue75) AS Revenue75
    FROM
    (
        SELECT
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Orders) OVER() AS Orders25,
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Revenue) OVER() AS Revenue75
        FROM CustomerMetrics
    ) X
)
SELECT
    CM.CustomerID,
    CM.Orders,
    CAST(CM.Revenue AS decimal(18,2)) AS Revenue,
    CAST(CM.Revenue / NULLIF(CM.Orders,0) AS decimal(18,2)) AS AOV
FROM CustomerMetrics CM
CROSS JOIN Thresholds T
WHERE CM.Orders <= T.Orders25
  AND CM.Revenue >= T.Revenue75
ORDER BY CM.Revenue DESC;
GO

--  Low-value, high-frequency customers
WITH CustomerMetrics AS
(
    SELECT
        CustomerID,
        COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
        SUM(SOD.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD
        ON SOH.SalesOrderID = SOD.SalesOrderID
    GROUP BY CustomerID
),
Thresholds AS
(
    SELECT
        MAX(Orders75) AS Orders75,
        MAX(Revenue25) AS Revenue25
    FROM
    (
        SELECT
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Orders) OVER() AS Orders75,
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Revenue) OVER() AS Revenue25
        FROM CustomerMetrics
    ) X
)
SELECT
    CM.CustomerID,
    CM.Orders,
    CAST(CM.Revenue AS decimal(18,2)) AS Revenue,
    CAST(CM.Revenue / NULLIF(CM.Orders,0) AS decimal(18,2)) AS AOV
FROM CustomerMetrics CM
CROSS JOIN Thresholds T
WHERE CM.Orders >= T.Orders75
  AND CM.Revenue <= T.Revenue25
ORDER BY CM.Orders DESC;
GO




--  Executive KPI table
SELECT
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS TotalSales,
    COUNT(DISTINCT SOH.SalesOrderID) AS TotalOrders,
    SUM(SOD.OrderQty) AS TotalQuantity,
    COUNT(DISTINCT SOH.CustomerID) AS TotalCustomers,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS decimal(18,2)) AS AOV,
    MIN(CAST(SOH.OrderDate AS date)) AS FirstOrderDate,
    MAX(CAST(SOH.OrderDate AS date)) AS LastOrderDate
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID;
GO

--  Product management summary
SELECT
    P.ProductID,
    P.Name AS ProductName,
    PC.Name AS Category,
    PSC.Name AS Subcategory,
    SUM(SOD.OrderQty) AS QuantitySold,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Revenue,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(SUM(SOD.OrderQty),0) AS decimal(18,2)) AS RevenuePerUnit,
    RANK() OVER(ORDER BY SUM(SOD.LineTotal) DESC) AS RevenueRank
FROM Sales.SalesOrderDetail SOD
JOIN Production.Product P ON SOD.ProductID = P.ProductID
LEFT JOIN Production.ProductSubcategory PSC
    ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
LEFT JOIN Production.ProductCategory PC
    ON PSC.ProductCategoryID = PC.ProductCategoryID
GROUP BY P.ProductID, P.Name, PC.Name, PSC.Name
ORDER BY Revenue DESC;
GO

--  Territory management summary
SELECT
    ST.TerritoryID,
    ST.Name AS Territory,
    ST.CountryRegionCode,
    ST.[Group] AS RegionGroup,
    CAST(SUM(SOD.LineTotal) AS decimal(18,2)) AS Revenue,
    COUNT(DISTINCT SOH.SalesOrderID) AS Orders,
    COUNT(DISTINCT SOH.CustomerID) AS Customers,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.SalesOrderID),0) AS decimal(18,2)) AS AOV,
    CAST(SUM(SOD.LineTotal) /
         NULLIF(COUNT(DISTINCT SOH.CustomerID),0) AS decimal(18,2))
         AS RevenuePerCustomer
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID
JOIN Sales.SalesTerritory ST
    ON SOH.TerritoryID = ST.TerritoryID
GROUP BY ST.TerritoryID, ST.Name, ST.CountryRegionCode, ST.[Group]
ORDER BY Revenue DESC;
GO

--  Customer segment management summary
WITH Segments AS
(
    SELECT
        *,
        CASE
            WHEN RecencyScore >= 4 AND FrequencyScore >= 4 AND MonetaryScore >= 4
                THEN 'Champions'
            WHEN RecencyScore >= 3 AND FrequencyScore >= 3 AND MonetaryScore >= 3
                THEN 'Loyal / High Value'
            WHEN RecencyScore >= 4 AND FrequencyScore <= 2
                THEN 'Recent / Potential'
            WHEN RecencyScore <= 2 AND MonetaryScore >= 4
                THEN 'At Risk - High Value'
            WHEN RecencyScore <= 2 AND FrequencyScore <= 2 AND MonetaryScore <= 2
                THEN 'Lost'
            ELSE 'Needs Attention'
        END AS CustomerSegment
    FROM #RFM
)
SELECT
    CustomerSegment,
    COUNT(*) AS Customers,
    CAST(SUM(MonetaryRevenue) AS decimal(18,2)) AS Revenue,
    CAST(AVG(FrequencyOrders) AS decimal(10,2)) AS AvgOrders,
    CAST(AVG(AOV) AS decimal(18,2)) AS AvgAOV,
    CAST(AVG(RecencyDays) AS decimal(10,2)) AS AvgRecencyDays
FROM Segments
GROUP BY CustomerSegment
ORDER BY Revenue DESC;
GO


SELECT
    SUM(SOD.LineTotal) AS TotalSales,
    COUNT(DISTINCT SOH.SalesOrderID) AS TotalOrders
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD
    ON SOH.SalesOrderID = SOD.SalesOrderID;