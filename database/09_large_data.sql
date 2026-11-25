-- =============================================================
-- 09_large_data.sql
-- Fills Bookings with 150,000 past bookings:
--   30 rooms x 5 time blocks per day x 1000 days = 150,000 rows
-- The blocks never overlap, so there are no conflicts.
-- Labs are booked by faculty, study rooms by students (rule 5).
-- Every 20th booking is cancelled, to look realistic.
--
-- Do these past bookings get slot rows?  YES: every ACTIVE booking gets
-- its BookingSlots rows (second INSERT below). Cancelled ones get none,
-- exactly like in the app.
--
-- How does the script avoid conflicts?  Each room gets exactly one booking
-- per block per day, and the 5 blocks never overlap. So no (RoomID, SlotStart)
-- pair is ever generated twice, and the primary key never complains.
--
-- Takes about 1 minute.
-- =============================================================
USE BookingDb;
GO

DECLARE @Today date = CAST(GETDATE() AS date);

;WITH Days AS (
    SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS d
    FROM sys.all_objects AS a CROSS JOIN sys.all_objects AS b
),
Blocks AS (   -- start and end in minutes after midnight
    SELECT * FROM (VALUES (1, 480, 540),    -- 08:00 - 09:00
                          (2, 540, 630),    -- 09:00 - 10:30
                          (3, 630, 720),    -- 10:30 - 12:00
                          (4, 750, 840),    -- 12:30 - 14:00
                          (5, 840, 960))    -- 14:00 - 16:00
           AS v(BlockNo, StartMin, EndMin)
),
Students AS (SELECT UserID, ROW_NUMBER() OVER (ORDER BY UserID) - 1 AS k FROM dbo.Users WHERE Role = 'Student'),
Faculty  AS (SELECT UserID, ROW_NUMBER() OVER (ORDER BY UserID) - 1 AS k FROM dbo.Users WHERE Role = 'Faculty'),
Base AS (
    SELECT r.RoomID, r.RoomType,
           DATEADD(MINUTE, b.StartMin, CAST(DATEADD(DAY, -d.d, @Today) AS datetime2(0))) AS StartTime,
           DATEADD(MINUTE, b.EndMin,   CAST(DATEADD(DAY, -d.d, @Today) AS datetime2(0))) AS EndTime,
           ROW_NUMBER() OVER (ORDER BY d.d, r.RoomID, b.BlockNo) AS n
    FROM dbo.Rooms AS r
    CROSS JOIN Days AS d
    CROSS JOIN Blocks AS b
)
INSERT INTO dbo.Bookings (UserID, RoomID, StartTime, EndTime, People, Status, CreatedAt)
SELECT CASE WHEN x.RoomType = 'Lab' THEN f.UserID ELSE s.UserID END,
       x.RoomID, x.StartTime, x.EndTime,
       2,
       CASE WHEN x.n % 20 = 0 THEN 'Cancelled' ELSE 'Active' END,
       DATEADD(DAY, -1, x.StartTime)
FROM Base AS x
JOIN Students AS s ON s.k = x.n % (SELECT COUNT(*) FROM Students)
JOIN Faculty  AS f ON f.k = x.n % (SELECT COUNT(*) FROM Faculty);
GO

-- Slots for the active bookings, so the history is consistent
INSERT INTO dbo.BookingSlots (RoomID, SlotStart, BookingID)
SELECT b.RoomID, s.SlotStart, b.BookingID
FROM dbo.Bookings AS b
CROSS APPLY dbo.fn_GetSlots(b.StartTime, b.EndTime) AS s
WHERE b.Status = 'Active';
GO

UPDATE STATISTICS dbo.Bookings;
UPDATE STATISTICS dbo.BookingSlots;
GO

SELECT (SELECT COUNT(*) FROM dbo.Bookings)     AS Bookings,
       (SELECT COUNT(*) FROM dbo.BookingSlots) AS BookingSlots;
