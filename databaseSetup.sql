/* Database Creation */
Create Database Duffman

USE Duffman;

/* End Database Creation */

/* Tables */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BULK_History](
	[StockName] [varchar](50) NOT NULL,
	[Price] [float] NOT NULL,
	[DateTraded] [datetime] NOT NULL
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BULK_Orders](
	[StockName] [varchar](50) NOT NULL,
	[Status] [varchar](50) NOT NULL,
	[BuyOrSell] [varchar](50) NOT NULL,
	[OrderType] [varchar](50) NOT NULL,
	[Shares] [int] NOT NULL,
	[ExpireType] [varchar](50) NOT NULL,
	[Price] [float] NOT NULL,
	[ClientOrderID] [varchar](100) NOT NULL
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BULK_Position](
	[StockName] [varchar](50) NOT NULL,
	[CurrentPrice] [float] NOT NULL,
	[EntryPrice] [float] NOT NULL
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BULK_Stock](
	[StockName] [varchar](50) NOT NULL,
	[Active] [int] NOT NULL,
	[Currency] [varchar](50) NOT NULL
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Config](
	[Description] [varchar](50) NOT NULL,
	[Value] [varchar](50) NOT NULL
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Orders](
	[OrderID] [int] IDENTITY(1,1) NOT NULL,
	[StockName] [varchar](50) NOT NULL,
	[Status] [varchar](50) NOT NULL,
	[BuyOrSell] [varchar](50) NOT NULL,
	[OrderType] [varchar](50) NOT NULL,
	[Shares] [int] NOT NULL,
	[ExpireType] [varchar](50) NOT NULL,
	[Price] [float] NOT NULL,
	[ClientOrderID] [varchar](100) NOT NULL,
	[DateCreated] [datetime] NULL,
	[DateModified] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Orders] ADD PRIMARY KEY CLUSTERED 
(
	[OrderID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ProfitShare](
	[CurrentProfit] [float] NOT NULL,
	[PercentageToShare] [int] NOT NULL,
	[AmountShared] [float] NOT NULL,
	[EndingProfit] [float] NOT NULL,
	[DateCreated] [datetime] NOT NULL
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Stock](
	[StockID] [int] IDENTITY(1,1) NOT NULL,
	[StockName] [varchar](50) NOT NULL,
	[Currency] [varchar](50) NULL,
	[Active] [int] NOT NULL,
	[HighAvg] [float] NULL,
	[LowAvg] [float] NULL,
	[Hits] [int] NULL,
	[FakeCapitol] [float] NULL,
	[RealCapitol] [float] NULL,
	[DateModified] [datetime] NULL,
	[DateCreated] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Stock] ADD PRIMARY KEY CLUSTERED 
(
	[StockID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

/* End Tables */

/* Stored Procedures */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[LastModifiedStock] 
AS
BEGIN

DECLARE @StockID int = 0;

SELECT TOP 1 @StockID = StockID 
FROM Stock
WHERE Active = 1
--WHERE StockName = 'DRIP'
ORDER BY ISNULL(DateModified, '1900-01-01') ASC

SELECT *
From Stock
WHERE StockID = @StockID

UPDATE Stock SET DateModified = GETDATE()
WHERE StockID = @StockID

END






GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[LiquidatePositions] AS
begin

BEGIN TRY
	IF EXISTS(SELECT 1 FROM tempdb.sys.objects WHERE name LIKE '%#pos%') BEGIN DROP TABLE #pos END
END TRY
BEGIN CATCH
END CATCH

SELECT p.StockName, SUM(o.Shares) as Shares, p.EntryPrice, p.CurrentPrice, o.Price, (SUM(p.CurrentPrice) * SUM(o.Shares)) - (SUM(p.EntryPrice) * SUM(o.Shares)) as Profit$, o.DateCreated
INTO #pos
FROM BULK_Position p 
JOIN Orders o ON p.StockName = o.StockName
WHERE o.BuyOrSell = 'sell' 
AND [Status] = 'new'
GROUP BY p.StockName, p.EntryPrice, p.CurrentPrice, o.DateCreated, o.Price
HAVING (SUM(p.CurrentPrice) * SUM(o.Shares)) - (SUM(p.EntryPrice) * SUM(o.Shares)) > 0

SELECT * 
FROM #pos p
WHERE (((p.DateCreated BETWEEN GETDate() - 5 AND GEtDate() - 10) OR (DATEPART(dw, GETDATE()) IN (6)) ) AND (((p.Price + p.EntryPrice) / 2) >= p.CurrentPrice)) --half profit within 5-10 days or it's Friday
OR (p.DateCreated < GETDATE() - 10) -- after 10 days liquidate
ORDER BY Profit$ DESC

END



GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[TradeCalculation]
AS 
BEGIN

DECLARE @Profit float, @Balance float, @Allowance float, @DayOfWeek int, @amountShared float, @percentage float, @ProfitThisWeek float, @endingProfit float;

SELECT @Profit = SUM(RealCapitol)
,@DayOfWeek = DATEPART(dw, GETDATE())
FROM Stock
WHERE RealCapitol > 0

UPDATE Config 
SET Value = CAST(@Profit as varchar)
WHERE Config.[Description] = 'Profit'

IF NOT EXISTS (SELECT 1 FROM ProfitShare WHERE CAST(DateCreated as date) = CAST(GETDATE() as date)  )
AND @DayOfWeek = 7
BEGIN 
    SELECT @percentage = CAST([Value] as int) 
    FROM Config
    WHERE [Description] = 'SharePercentage'

    SELECT @percentage = @percentage * 0.01;

    SELECT @ProfitThisWeek = SUM(SellOrders.Price * SellOrders.Shares) - SUM(BuyOrders.Price * BuyOrders.Shares)
    FROM orders SellOrders
    JOIN orders BuyOrders  ON SellOrders.StockName = BuyOrders.StockName
    WHERE SellOrders.BuyOrSell = 'Sell'
    AND BuyOrders.BuyOrSell = 'Buy'
    AND BuyOrders.Status = 'filled'
    AND SellOrders.Status = 'filled'
    AND SellOrders.DateModified BETWEEN GETDATE() - 6 AND GETDATE()

    INSERT INTO ProfitShare (CurrentProfit, PercentageToShare, AmountShared, EndingProfit, DateCreated) 
    VALUES (@Profit, @percentage, @ProfitThisWeek * @percentage, @Profit - (@ProfitThisWeek * @percentage), GETDATE() )
END

SELECT @amountShared = SUM(AmountShared) FROM ProfitShare 

SELECT @Balance = Value
FROM Config
WHERE Description = 'Balance'

SELECT @Allowance = @Balance - (@Profit - @amountShared);

UPDATE Config SET Value = CAST(@Allowance as varchar)
WHERE [Description] = 'Allowance'
AND @Balance >= @Profit;

SELECT TOP 10 * 
FROM (
    SELECT DISTINCT BuyOrders.StockName
    , BuyOrders.Shares
    , BuyOrders.[Status]
    , BuyOrders.BoughtPrice
    , ROUND(s.HighAvg, 3) as 'PriceToTrade'
    , 'limit' as OrderType
    , 'gtc' as ExpireType
    , 'sell' as Action
    , s.Hits
    , ROUND(s.FakeCapitol, 0) AS FakeCapitol
    , ISNULL(s.RealCapitol, ROUND((BuyOrders.Shares * s.HighAvg) - (BuyOrders.Shares * BuyOrders.BoughtPrice),2) ) as RealCapitol --Expected Profit 
    , @Allowance as Allowance
    FROM
    (
        SELECT Stockname, Shares, Status, Price as BoughtPrice
        FROM Orders o 
        WHERE Status IN ('filled', 'new', 'accepted')
        AND BuyOrSell = 'Buy'
    ) as BuyOrders
    LEFT JOIN (
        SELECT Stockname, Shares, Status
        FROM Orders o 
        WHERE Status IN ('filled', 'new', 'accepted')
        AND BuyOrSell = 'Sell'
    ) SellOrders ON BuyOrders.StockName = SellOrders.StockName
    JOIN Stock s ON BuyOrders.StockName = s.StockName
    WHERE SellOrders.StockName IS NULL
    AND BuyOrders.Status = 'filled'
    UNION ALL
    SELECT s.StockName
    , ( ROUND(@Allowance / s.LowAvg, 0) -1 ) as Shares
    , '' as Status
    , ( ( ROUND(@Allowance / s.LowAvg, 0) -1 ) * ROUND(s.LowAvg, 2) ) as BoughtPrice
    , ROUND(s.LowAvg, 2) as PriceToTrade
    , 'limit' as OrderType
    , 'day' as ExpireType
    , 'buy' as Action
    , s.Hits
    , ROUND(s.FakeCapitol, 0) AS FakeCapitol
    , ISNULL(s.RealCapitol, ROUND((s.HighAvg * ( ROUND(@Allowance / s.LowAvg, 0) -1 ) - ( ( ROUND(@Allowance / s.LowAvg, 0) -1 ) * ROUND(s.LowAvg, 2) ) ), 2)) as RealCapitol --Expected Profit 
    , @Allowance as Allowance
    FROM (
        SELECT TOP 100 StockName FROM Stock ORDER BY Hits DESC
    ) hits
    JOIN (
        SELECT TOP 100 StockName FROM Stock ORDER BY FakeCapitol DESC
    ) cap ON hits.StockName = cap.StockName
    JOIN Stock s ON cap.StockName = s.StockName
    LEFT JOIN Orders o ON s.StockName = o.StockName AND o.Status IN ('new', 'accepted')
    WHERE o.OrderID IS NULL 
    AND @Balance >= @Profit --Balance must always be more than profit
    AND @Allowance >= ( ( ROUND(@Allowance / s.LowAvg, 0) -1 ) * (ROUND(s.LowAvg, 2)) ) --Allowance greater than Price * Shares
    AND ROUND(@Allowance / s.LowAvg, 0) > 5 --At least 5 Shares
) x
WHERE NOT EXISTS (SELECT 1 FROM Stock WHERE DateModified IS NULL) --All stocks must be updated
ORDER BY x.Action DESC, x.RealCapitol DESC

END



GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Upd_Imitation] 
@Symbol varchar(50)
,@Profit float
,@Hits int

AS
BEGIN

	UPDATE Stock SET FakeCapitol = @Profit, Hits = @Hits
	WHERE StockName = @Symbol

END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[UpdateAverageStock] AS
BEGIN

DECLARE @AvgMin float, @AvgMax float, @StockName varchar(50)

BEGIN TRY
	IF EXISTS(SELECT 1 FROM tempdb.sys.objects WHERE name LIKE '%#Avgs%') BEGIN DROP TABLE #Avgs END
END TRY
BEGIN CATCH
END CATCH

SELECT top 1 @StockName = StockName
FROM Bulk_History


SELECT MAX(Price) as AvgHigh, MIN(Price) as AvgLow, CAST(DateTraded as date) as DateOfStock
INTO #Avgs
FROM BULK_History bh
GROUP BY CAST(DateTraded as date)

SELECT @AvgMax = Avg(AvgHigh), @AvgMin = Avg(AvgLow)
FROM #Avgs

UPDATE Stock
SET HighAvg = @AvgMax, LowAvg = @AvgMin
WHERE StockName = @StockName

SELECT @AvgMax as HighAvg, @AvgMin as LowAvg

end



GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpsertOrders] AS
BEGIN 

UPDATE Orders 
SET Orders.Status = bo.STATUS
, Orders.Price = bo.Price
, Orders.DateModified = GETDATE()
FROM BULK_Orders bo
WHERE Orders.StockName = bo.StockName
AND bo.ClientOrderID = Orders.ClientOrderID
AND (Orders.Price != bo.Price 
    OR Orders.[Status] != bo.[Status])

INSERT INTO Orders 
SELECT bo.[StockName]
      ,bo.[Status]
      ,bo.[BuyOrSell]
      ,bo.[OrderType]
      ,bo.[Shares]
      ,bo.[ExpireType]
      ,bo.[Price]
      ,bo.[ClientOrderID]
      ,GETDate()
      ,GetDate()
  FROM [BULK_Orders] bo 
  LEFT JOIN Orders o ON bo.StockName = o.StockName AND bo.ClientOrderID = o.ClientOrderID
  WHERE o.OrderID IS NULL


UPDATE Stock
SET Stock.RealCapitol = x.Profit
FROM (
  SELECT SUM(SellOrders.Price * SellOrders.Shares) - SUM(BuyOrders.Price * BuyOrders.Shares) as Profit, SellOrders.StockName
  FROM orders SellOrders
  JOIN orders BuyOrders  ON SellOrders.StockName = BuyOrders.StockName
  WHERE SellOrders.BuyOrSell = 'Sell'
  AND BuyOrders.BuyOrSell = 'Buy'
  AND BuyOrders.Status = 'filled'
  AND SellOrders.Status = 'filled'
  GROUP BY SellOrders.StockName ) x
WHERE Stock.StockName = x.StockName

DELETE FROM Orders 
WHERE [Status] = 'Canceled'
AND DateCreated > GETDATE() - 30

END






GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpsertStock] 
as 
BEGIN 
    INSERT INTO Stock (StockName, Active, Currency, DateCreated)
    SELECT bs.StockName, bs.Active, bs.Currency, GETDATE()
    FROM BULK_Stock bs
    LEFT JOIN Stock s ON bs.StockName = s.StockName
    WHERE s.StockName IS NULL

    TRUNCATE TABLE BULK_Stock;
END


GO

 /* End Stored Procedures */

 /* Data Setup */

  INSERT INTO Config VALUES ('Balance', '0')
INSERT INTO Config VALUES ('Profit', '0')
INSERT INTO Config VALUES ('Allowance', '0')
INSERT INTO Config VALUES ('Day Trade Policy', '1')
INSERT INTO Config VALUES ('Trading Fee', '0')
INSERT INTO Config VALUES ('Bracket Orders', '0')

/* End Data Setup */