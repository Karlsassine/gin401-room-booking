-- =============================================================
-- 12c_concurrency_cleanup.sql
-- Deletes the bookings made by 12a and 12b (day after tomorrow, 08:00).
-- =============================================================
USE BookingDb;
GO
DECLARE @At0800 datetime2(0) = DATEADD(HOUR, 8, CAST(DATEADD(DAY, 2, CAST(GETDATE() AS date)) AS datetime2(0)));

DELETE ls FROM dbo.LoanSlots ls JOIN dbo.EquipmentLoans l ON l.LoanID = ls.LoanID
          JOIN dbo.Bookings b ON b.BookingID = l.BookingID WHERE b.StartTime = @At0800;
DELETE l  FROM dbo.EquipmentLoans l JOIN dbo.Bookings b ON b.BookingID = l.BookingID WHERE b.StartTime = @At0800;
DELETE s  FROM dbo.BookingSlots s   JOIN dbo.Bookings b ON b.BookingID = s.BookingID WHERE b.StartTime = @At0800;
DELETE FROM dbo.Bookings WHERE StartTime = @At0800;
PRINT 'Demo bookings deleted.';
