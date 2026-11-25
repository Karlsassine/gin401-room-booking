-- =============================================================
-- 12c_concurrency_cleanup.sql
-- Deletes the bookings made by 12a and 12b (all of the day after tomorrow).
-- =============================================================
USE BookingDb;
GO
DECLARE @D datetime2(0) = CAST(DATEADD(DAY, 2, CAST(GETDATE() AS date)) AS datetime2(0));
DECLARE @Next datetime2(0) = DATEADD(DAY, 1, @D);

DELETE ls FROM dbo.LoanSlots ls JOIN dbo.EquipmentLoans l ON l.LoanID = ls.LoanID
          JOIN dbo.Bookings b ON b.BookingID = l.BookingID WHERE b.StartTime >= @D AND b.StartTime < @Next;
DELETE l  FROM dbo.EquipmentLoans l JOIN dbo.Bookings b ON b.BookingID = l.BookingID WHERE b.StartTime >= @D AND b.StartTime < @Next;
DELETE s  FROM dbo.BookingSlots s   JOIN dbo.Bookings b ON b.BookingID = s.BookingID WHERE b.StartTime >= @D AND b.StartTime < @Next;
DELETE FROM dbo.Bookings WHERE StartTime >= @D AND StartTime < @Next;
PRINT 'Demo bookings deleted.';
