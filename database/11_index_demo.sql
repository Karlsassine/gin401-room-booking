-- =============================================================
-- 11_index_demo.sql
-- Logical reads of the 3 main queries, WITHOUT and WITH the
-- covering indexes (design doc, section 6).
--
-- How to use:
--   1. In SSMS press Ctrl+M ("Include Actual Execution Plan").
--   2. Run the whole script.
--   3. "Messages" tab: write down "logical reads" on table 'Bookings'
--      for each query, in PART A and PART B. Fill this table:
--
--        Query                     | Without index | With index
--        1. My bookings            |               |
--        2. Room schedule (1 day)  |               |
--        3. Report (1 month)       |               |
--
--   4. "Execution plan" tab: PART A shows "Clustered Index Scan" (reads
--      the whole table); PART B shows "Index Seek" and no "Key Lookup"
--      (the index covers the query). Take screenshots.
--
-- The queries are the same as in the procedures, but use past dates,
-- because the 150,000 generated bookings are all in the past.
-- =============================================================
USE BookingDb;
GO
SET STATISTICS IO ON;
GO

DECLARE @UserID int  = (SELECT UserID FROM dbo.Users WHERE Email = 'student001@uni.edu');
DECLARE @RoomID int  = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-101');
DECLARE @Since  datetime2(0) = DATEADD(MONTH, -1, SYSDATETIME());
DECLARE @Day    date = DATEADD(DAY, -30, CAST(GETDATE() AS date));
DECLARE @From   date = DATEADD(MONTH, -2, CAST(GETDATE() AS date));
DECLARE @To     date = DATEADD(MONTH, -1, CAST(GETDATE() AS date));

/* ===================== PART A: WITHOUT the indexes ===================== */
DROP INDEX IF EXISTS IX_Bookings_User         ON dbo.Bookings;
DROP INDEX IF EXISTS IX_Bookings_Room         ON dbo.Bookings;
DROP INDEX IF EXISTS IX_Bookings_Status_Start ON dbo.Bookings;

PRINT '===== PART A: WITHOUT INDEXES =====';
PRINT '--- Query 1 ---';
SELECT BookingID, RoomID, StartTime, EndTime, People FROM dbo.Bookings
WHERE UserID = @UserID AND Status = 'Active' AND StartTime >= @Since ORDER BY StartTime;
PRINT '--- Query 2 ---';
SELECT BookingID, UserID, StartTime, EndTime, People FROM dbo.Bookings
WHERE RoomID = @RoomID AND Status = 'Active' AND StartTime >= @Day AND StartTime < DATEADD(DAY, 1, @Day);
PRINT '--- Query 3 ---';
SELECT RoomID, COUNT(*) AS TotalBookings FROM dbo.Bookings
WHERE Status = 'Active' AND StartTime >= @From AND StartTime < DATEADD(DAY, 1, @To) GROUP BY RoomID;

/* ===================== PART B: WITH the covering indexes ===================== */
CREATE INDEX IX_Bookings_User         ON dbo.Bookings (UserID, Status, StartTime) INCLUDE (RoomID, EndTime, People);
CREATE INDEX IX_Bookings_Room         ON dbo.Bookings (RoomID, Status, StartTime) INCLUDE (UserID, EndTime, People);
CREATE INDEX IX_Bookings_Status_Start ON dbo.Bookings (Status, StartTime) INCLUDE (RoomID);

PRINT '===== PART B: WITH COVERING INDEXES =====';
PRINT '--- Query 1 ---';
SELECT BookingID, RoomID, StartTime, EndTime, People FROM dbo.Bookings
WHERE UserID = @UserID AND Status = 'Active' AND StartTime >= @Since ORDER BY StartTime;
PRINT '--- Query 2 ---';
SELECT BookingID, UserID, StartTime, EndTime, People FROM dbo.Bookings
WHERE RoomID = @RoomID AND Status = 'Active' AND StartTime >= @Day AND StartTime < DATEADD(DAY, 1, @Day);
PRINT '--- Query 3 ---';
SELECT RoomID, COUNT(*) AS TotalBookings FROM dbo.Bookings
WHERE Status = 'Active' AND StartTime >= @From AND StartTime < DATEADD(DAY, 1, @To) GROUP BY RoomID;
GO

SET STATISTICS IO OFF;
GO
