-- =============================================================
-- 12b_concurrency_window2.sql
-- Run this in a SECOND window while 12a is waiting.
-- =============================================================
USE BookingDb;
GO
SET NOCOUNT ON;

DECLARE @D datetime2(0) = CAST(DATEADD(DAY, 2, CAST(GETDATE() AS date)) AS datetime2(0));
DECLARE @At0800 datetime2(0) = DATEADD(HOUR, 8, @D), @At0900 datetime2(0) = DATEADD(HOUR, 9, @D);
DECLARE @At1100 datetime2(0) = DATEADD(HOUR, 11, @D), @At1200 datetime2(0) = DATEADD(HOUR, 12, @D);
DECLARE @Sara  int = (SELECT UserID FROM dbo.Users WHERE Email = 'sara@uni.edu');
DECLARE @Admin int = (SELECT UserID FROM dbo.Users WHERE Email = 'admin@uni.edu');
DECLARE @Projector int = (SELECT EquipmentID FROM dbo.Equipment WHERE Name = 'Projector');
DECLARE @S113 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-113');
DECLARE @S121 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-121');

-- Demo 1: Sara's 4th booking at the same time as her 3rd.
-- It WAITS for window 1 (Sara's row is locked), then the trigger counts 3 -> refused.
-- Without the lock, both triggers would count 2 and both bookings would pass.
BEGIN TRY
    EXEC dbo.sp_CreateBooking @UserID = @Sara, @RoomID = @S113, @Start = @At1100, @End = @At1200, @People = 1;
    PRINT 'FAIL: Sara got a 4th booking';
END TRY
BEGIN CATCH PRINT 'PASS (refused after waiting): ' + ERROR_MESSAGE(); END CATCH;

-- Demo 2: the admin also wants 1 projector at the same time as Bruno.
-- It WAITS for window 1 (the Projector type is locked), then sees that
-- Bruno took PRJ-01 and picks PRJ-02. No error, because another unit was free.
BEGIN TRY
    EXEC dbo.sp_CreateBooking @UserID = @Admin, @RoomID = @S121, @Start = @At0800, @End = @At0900, @People = 1,
                              @EquipmentID = @Projector, @Quantity = 1;
    PRINT 'PASS: the admin got another free projector';
END TRY
BEGIN CATCH PRINT 'FAIL: ' + ERROR_MESSAGE(); END CATCH;

-- Which units were lent?
SELECT b.BookingID, u.FullName, eu.SerialNumber
FROM dbo.EquipmentLoans l
JOIN dbo.Bookings b        ON b.BookingID = l.BookingID
JOIN dbo.Users u           ON u.UserID = b.UserID
JOIN dbo.EquipmentUnits eu ON eu.UnitID = l.UnitID
WHERE b.StartTime = @At0800;
