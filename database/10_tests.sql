-- =============================================================
-- 10_tests.sql
-- Proof that the database enforces every rule.
-- Each test tries to break a rule and prints PASS or FAIL.
-- Run it in SSMS and look at the "Messages" tab.
-- Run it when nobody has booked rooms for tomorrow in the app yet.
-- At the end, all test bookings are deleted again.
-- =============================================================
USE BookingDb;
GO
SET NOCOUNT ON;

DECLARE @TestStart datetime2(0) = DATEADD(SECOND, -1, SYSDATETIME());
DECLARE @Tomorrow  datetime2(0) = CAST(DATEADD(DAY, 1, CAST(GETDATE() AS date)) AS datetime2(0));
DECLARE @At0800 datetime2(0) = DATEADD(HOUR, 8,  @Tomorrow);
DECLARE @At0900 datetime2(0) = DATEADD(HOUR, 9,  @Tomorrow);
DECLARE @At1000 datetime2(0) = DATEADD(HOUR, 10, @Tomorrow);
DECLARE @At1030 datetime2(0) = DATEADD(MINUTE, 630, @Tomorrow);
DECLARE @At1100 datetime2(0) = DATEADD(HOUR, 11, @Tomorrow);
DECLARE @At1130 datetime2(0) = DATEADD(MINUTE, 690, @Tomorrow);
DECLARE @At1200 datetime2(0) = DATEADD(HOUR, 12, @Tomorrow);
DECLARE @At1300 datetime2(0) = DATEADD(HOUR, 13, @Tomorrow);
DECLARE @At1400 datetime2(0) = DATEADD(HOUR, 14, @Tomorrow);
DECLARE @At1700 datetime2(0) = DATEADD(HOUR, 17, @Tomorrow);
DECLARE @At1800 datetime2(0) = DATEADD(HOUR, 18, @Tomorrow);

DECLARE @Admin int = (SELECT UserID FROM dbo.Users WHERE Email = 'admin@uni.edu');
DECLARE @Bruno int = (SELECT UserID FROM dbo.Users WHERE Email = 'bruno@uni.edu');
DECLARE @Karl  int = (SELECT UserID FROM dbo.Users WHERE Email = 'karl@uni.edu');
DECLARE @JM    int = (SELECT UserID FROM dbo.Users WHERE Email = 'jeanmichel@uni.edu');
DECLARE @Sara  int = (SELECT UserID FROM dbo.Users WHERE Email = 'sara@uni.edu');

DECLARE @S101 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-101');
DECLARE @S102 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-102');
DECLARE @S103 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-103');
DECLARE @S104 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-104');
DECLARE @S110 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'S-110');
DECLARE @Lab1 int = (SELECT RoomID FROM dbo.Rooms WHERE RoomName = 'LAB-1');
DECLARE @Projector int = (SELECT EquipmentID FROM dbo.Equipment WHERE Name = 'Projector');
-- How many projectors exist (3 at the start, more if an admin added some)
DECLARE @ProjectorUnits int = (SELECT COUNT(*) FROM dbo.EquipmentUnits WHERE EquipmentID = @Projector);

-- Put LAB-1 back to its original capacity, in case it was edited in the admin page
UPDATE dbo.Rooms SET Capacity = 25 WHERE RoomName = 'LAB-1';

DECLARE @Id int;

PRINT '--- Rule 1: opening hours (08:00 - 16:00) ---';
BEGIN TRY
    EXEC dbo.sp_CreateBooking @UserID = @Karl, @RoomID = @S101, @Start = @At1700, @End = @At1800, @People = 2;
    PRINT 'FAIL: a booking at 17:00 was accepted';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

PRINT '--- Rule 2: booking length (max 2 hours, on :00 or :30) ---';
BEGIN TRY
    EXEC dbo.sp_CreateBooking @UserID = @Karl, @RoomID = @S101, @Start = @At0800, @End = @At1100, @People = 2;
    PRINT 'FAIL: a 3-hour booking was accepted';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
    DECLARE @At0815 datetime2(0) = DATEADD(MINUTE, 495, @Tomorrow);
    EXEC dbo.sp_CreateBooking @UserID = @Karl, @RoomID = @S101, @Start = @At0815, @End = @At0900, @People = 2;
    PRINT 'FAIL: a booking starting at 08:15 was accepted';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

PRINT '--- Rule 4: room capacity ---';
BEGIN TRY
    EXEC dbo.sp_CreateBooking @UserID = @Karl, @RoomID = @S101, @Start = @At0800, @End = @At0900, @People = 50;
    PRINT 'FAIL: 50 people in a small room was accepted';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

PRINT '--- Rule 5: only faculty and admins can book labs ---';
BEGIN TRY
    EXEC dbo.sp_CreateBooking @UserID = @Karl, @RoomID = @Lab1, @Start = @At0800, @End = @At0900, @People = 5;
    PRINT 'FAIL: a student booked a lab';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
    EXEC dbo.sp_CreateBooking @UserID = @Bruno, @RoomID = @Lab1, @Start = @At0800, @End = @At0900, @People = 5;
    PRINT 'PASS: faculty booked a lab';
END TRY
BEGIN CATCH PRINT 'FAIL: faculty could not book a lab: ' + ERROR_MESSAGE(); END CATCH;

PRINT '--- Rule 3: max 3 upcoming bookings per student ---';
BEGIN TRY
    EXEC dbo.sp_CreateBooking @UserID = @Karl, @RoomID = @S101, @Start = @At0800, @End = @At0900, @People = 2;
    EXEC dbo.sp_CreateBooking @UserID = @Karl, @RoomID = @S102, @Start = @At0900, @End = @At1000, @People = 2;
    EXEC dbo.sp_CreateBooking @UserID = @Karl, @RoomID = @S103, @Start = @At1000, @End = @At1100, @People = 2;
    PRINT 'PASS: 3 bookings accepted';
END TRY
BEGIN CATCH PRINT 'FAIL: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
    EXEC dbo.sp_CreateBooking @UserID = @Karl, @RoomID = @S104, @Start = @At1200, @End = @At1300, @People = 2;
    PRINT 'FAIL: a 4th booking was accepted';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

PRINT '--- Rule 6: no double booking ---';
-- Jean Michel books S-104 from 10:00 to 11:00
EXEC dbo.sp_CreateBooking @UserID = @JM, @RoomID = @S104, @Start = @At1000, @End = @At1100, @People = 2;

BEGIN TRY  -- Sara tries 10:30 - 11:30 in the same room: overlaps
    EXEC dbo.sp_CreateBooking @UserID = @Sara, @RoomID = @S104, @Start = @At1030, @End = @At1130, @People = 2;
    PRINT 'FAIL: an overlapping booking was accepted';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY  -- Sara tries 11:00 - 12:00: right after, no overlap
    EXEC dbo.sp_CreateBooking @UserID = @Sara, @RoomID = @S104, @Start = @At1100, @End = @At1200, @People = 2;
    PRINT 'PASS: a back-to-back booking was accepted';
END TRY
BEGIN CATCH PRINT 'FAIL: ' + ERROR_MESSAGE(); END CATCH;

PRINT '--- Rule 9: a user cannot have two bookings at the same time ---';
BEGIN TRY  -- Sara has S-104 from 11:00 to 12:00; she tries S-110 from 11:30
    EXEC dbo.sp_CreateBooking @UserID = @Sara, @RoomID = @S110, @Start = @At1130, @End = @At1200, @People = 2;
    PRINT 'FAIL: two bookings at the same time were accepted';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

PRINT CONCAT('--- Rule 7: never lend more units than we have (', @ProjectorUnits, ' projectors) ---');
BEGIN TRY  -- Bruno takes ALL the projectors
    EXEC dbo.sp_CreateBooking @UserID = @Bruno, @RoomID = @S102, @Start = @At1200, @End = @At1300, @People = 2,
                              @EquipmentID = @Projector, @Quantity = @ProjectorUnits;
    PRINT CONCAT('PASS: all ', @ProjectorUnits, ' projectors lent');
END TRY
BEGIN CATCH PRINT 'FAIL: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY  -- one more than we have
    EXEC dbo.sp_CreateBooking @UserID = @JM, @RoomID = @S103, @Start = @At1200, @End = @At1300, @People = 2,
                              @EquipmentID = @Projector, @Quantity = 1;
    PRINT 'FAIL: more projectors were lent than we have';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

PRINT '--- Transaction: a failed booking leaves nothing behind ---';
DECLARE @Before int = (SELECT COUNT(*) FROM dbo.Bookings);
BEGIN TRY
    -- the room is free, but the projectors are not, so step 3 fails
    EXEC dbo.sp_CreateBooking @UserID = @Sara, @RoomID = @S101, @Start = @At1200, @End = @At1300, @People = 2,
                              @EquipmentID = @Projector, @Quantity = 1;
END TRY
BEGIN CATCH PRINT 'Refused as expected: ' + ERROR_MESSAGE(); END CATCH;
IF (SELECT COUNT(*) FROM dbo.Bookings) = @Before
   AND NOT EXISTS (SELECT 1 FROM dbo.BookingSlots WHERE RoomID = @S101 AND SlotStart = @At1200)
    PRINT 'PASS: no booking row and no slot row were left behind (ROLLBACK worked)';
ELSE
    PRINT 'FAIL: something was left behind';

PRINT '--- Rule 8: cancelling ---';
SELECT @Id = BookingID FROM dbo.Bookings WHERE UserID = @JM AND RoomID = @S104 AND StartTime = @At1000;

BEGIN TRY  -- Sara tries to cancel Jean Michel's booking
    EXEC dbo.sp_CancelBooking @BookingID = @Id, @ActingUserID = @Sara;
    PRINT 'FAIL: someone else cancelled the booking';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY  -- Jean Michel cancels his own booking
    EXEC dbo.sp_CancelBooking @BookingID = @Id, @ActingUserID = @JM;
    PRINT 'PASS: the owner cancelled the booking';
END TRY
BEGIN CATCH PRINT 'FAIL: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY  -- the room is free again, so Sara can now book 10:00 - 11:00
    EXEC dbo.sp_CreateBooking @UserID = @Sara, @RoomID = @S104, @Start = @At1000, @End = @At1100, @People = 2;
    PRINT 'PASS: after cancelling, the room was free again';
END TRY
BEGIN CATCH PRINT 'FAIL: ' + ERROR_MESSAGE(); END CATCH;

PRINT '--- Rule 4 (protected): lowering a room capacity below an upcoming booking ---';
BEGIN TRY
    EXEC dbo.sp_CreateBooking @UserID = @Bruno, @RoomID = @Lab1, @Start = @At1300,
                              @End = @At1400, @People = 15;
    EXEC dbo.sp_AddRoom @ActingUserID = @Admin, @RoomID = @Lab1, @RoomName = 'LAB-1', @RoomType = 'Lab', @Capacity = 10;
    PRINT 'FAIL: capacity was lowered below an upcoming booking';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

PRINT '--- Rule 3: cancelled bookings are not counted ---';
-- Karl has 3 upcoming bookings (S-101 08:00, S-102 09:00, S-103 10:00). He cancels one...
SELECT @Id = BookingID FROM dbo.Bookings WHERE UserID = @Karl AND RoomID = @S103 AND StartTime = @At1000;
EXEC dbo.sp_CancelBooking @BookingID = @Id, @ActingUserID = @Karl;
BEGIN TRY  -- ...so he can book again
    EXEC dbo.sp_CreateBooking @UserID = @Karl, @RoomID = @S103, @Start = @At1300, @End = @At1400, @People = 2;
    PRINT 'PASS: after cancelling, the student could book again';
END TRY
BEGIN CATCH PRINT 'FAIL: ' + ERROR_MESSAGE(); END CATCH;

PRINT '--- Composite foreign key: a slot must have the same room as its booking ---';
-- @Id is a booking in S-103. Try to save one of its slots under S-101.
BEGIN TRY
    INSERT INTO dbo.BookingSlots (RoomID, SlotStart, BookingID)
    VALUES (@S101, DATEADD(HOUR, 15, @Tomorrow), @Id);
    PRINT 'FAIL: a slot with the wrong room was accepted';
END TRY
BEGIN CATCH PRINT 'PASS (refused): ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Clean up: delete everything the tests created ----------
DELETE ls FROM dbo.LoanSlots ls JOIN dbo.EquipmentLoans l ON l.LoanID = ls.LoanID
          JOIN dbo.Bookings b ON b.BookingID = l.BookingID WHERE b.CreatedAt >= @TestStart;
DELETE l  FROM dbo.EquipmentLoans l JOIN dbo.Bookings b ON b.BookingID = l.BookingID WHERE b.CreatedAt >= @TestStart;
DELETE s  FROM dbo.BookingSlots s   JOIN dbo.Bookings b ON b.BookingID = s.BookingID WHERE b.CreatedAt >= @TestStart;
DELETE FROM dbo.Bookings WHERE CreatedAt >= @TestStart;
PRINT '--- Test data deleted ---';
