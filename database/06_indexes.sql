-- =============================================================
-- 06_indexes.sql
-- One COVERING index per main query on the large table Bookings.
-- "Covering" = the index holds every column the query needs
-- (keys + INCLUDE), so SQL Server never has to read the table itself.
-- BookingID is the clustered key, so every index already contains it.
-- See 11_index_demo.sql for the before/after logical reads.
-- =============================================================
USE BookingDb;
GO

-- Query 1 (sp_GetMyBookings) and the rule 3 count in the trigger:
--   WHERE UserID = @UserID AND Status = 'Active' AND StartTime >= now  ORDER BY StartTime
CREATE INDEX IX_Bookings_User
    ON dbo.Bookings (UserID, Status, StartTime)
    INCLUDE (RoomID, EndTime, People);

-- Query 2 (sp_GetRoomSchedule):
--   WHERE RoomID = @RoomID AND Status = 'Active' AND StartTime in one day
CREATE INDEX IX_Bookings_Room
    ON dbo.Bookings (RoomID, Status, StartTime)
    INCLUDE (UserID, EndTime, People);

-- Query 3 (sp_RoomReport):
--   WHERE Status = 'Active' AND StartTime between two dates  GROUP BY RoomID
CREATE INDEX IX_Bookings_Status_Start
    ON dbo.Bookings (Status, StartTime)
    INCLUDE (RoomID);

-- Helper indexes so that cancelling a booking finds its slots and loans fast
CREATE INDEX IX_BookingSlots_Booking   ON dbo.BookingSlots (BookingID);
CREATE INDEX IX_EquipmentLoans_Booking ON dbo.EquipmentLoans (BookingID);
CREATE INDEX IX_LoanSlots_Loan         ON dbo.LoanSlots (LoanID);
GO
