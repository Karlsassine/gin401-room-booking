-- =============================================================
-- 12a_concurrency_window1.sql   (run together with 12b)
-- Shows that the two locks in sp_CreateBooking work.
--
-- 1. Open THIS file in one SSMS window and 12b in a second window.
-- 2. Run this one (F5). It keeps its transaction open for 15 seconds.
-- 3. Within those 15 seconds, run 12b in the other window.
-- 4. Watch 12b WAIT, then give the correct result.
-- 5. At the end, run 12c_concurrency_cleanup.sql.
-- =============================================================
USE BookingDb;
GO
SET NOCOUNT ON;

DECLARE @D datetime2(0) = CAST(DATEADD(DAY, 2, CAST(GETDATE() AS date)) AS datetime2(0));  -- day after tomorrow
DECLARE @At0800 datetime2(0) = DATEADD(HOUR, 8, @D), @At0900 datetime2(0) = DATEADD(HOUR, 9, @D);
DECLARE @At1000 datetime2(0) = DATEADD(HOUR, 10, @D), @At1100 datetime2(0) = DATEADD(HOUR, 11, @D);
DECLARE @Sara  int = (SELECT UserID FROM dbo.Users WHERE Email = 'sara@uni.edu');
DECLARE @Bruno int = (SELECT UserID FROM dbo.Users WHERE Email = 'bruno@uni.edu');
DECLARE @Projector int = (SELECT EquipmentID FROM dbo.Equipment WHERE Name = 'Projector');   -- 3 units
DECLARE @S110 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-110');
DECLARE @S111 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-111');
DECLARE @S112 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-112');
DECLARE @S120 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-120');

-- Setup: Sara already has 2 upcoming bookings
EXEC dbo.sp_CreateBooking @UserID = @Sara, @RoomID = @S110, @Start = @At0800, @End = @At0900, @People = 1;
EXEC dbo.sp_CreateBooking @UserID = @Sara, @RoomID = @S111, @Start = @At0900, @End = @At1000, @People = 1;

BEGIN TRANSACTION;   -- keeps the locks for 15 seconds

    -- Demo 1 (rule 3): Sara's 3rd booking. Locks Sara's row in Users.
    EXEC dbo.sp_CreateBooking @UserID = @Sara, @RoomID = @S112, @Start = @At1000, @End = @At1100, @People = 1;

    -- Demo 2 (equipment): Bruno takes 1 projector. Locks the "Projector" row in Equipment.
    EXEC dbo.sp_CreateBooking @UserID = @Bruno, @RoomID = @S120, @Start = @At0800, @End = @At0900, @People = 1,
                              @EquipmentID = @Projector, @Quantity = 1;

    PRINT 'Window 1: holding the locks for 15 seconds... run 12b now.';
    WAITFOR DELAY '00:00:15';

COMMIT TRANSACTION;
PRINT 'Window 1: committed. Sara now has 3 bookings; Bruno has 1 projector.';
