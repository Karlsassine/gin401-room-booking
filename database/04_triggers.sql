-- =============================================================
-- 04_triggers.sql
-- =============================================================
USE BookingDb;
GO

-- Runs after every new booking. Checks rules 3, 4 and 5.
-- If one is broken, THROW cancels the insert (and the whole transaction).
CREATE OR ALTER TRIGGER dbo.trg_Bookings_CheckRules
ON dbo.Bookings
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Rule 4: room capacity
    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.Rooms AS r ON r.RoomID = i.RoomID
               WHERE i.People > r.Capacity)
        THROW 50004, 'Too many people for this room.', 1;

    -- Rule 5: only faculty and admins can book labs
    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.Rooms AS r ON r.RoomID = i.RoomID
               JOIN dbo.Users AS u ON u.UserID = i.UserID
               WHERE r.RoomType = 'Lab' AND u.Role = 'Student')
        THROW 50005, 'Only faculty and admins can book labs.', 1;

    -- Rule 3: a student can have at most 3 upcoming active bookings.
    -- Cancelled bookings are not counted. Two bookings sent at the same second
    -- cannot both pass, because sp_CreateBooking first locks the user's row
    -- (UPDLOCK, HOLDLOCK), so the second request waits for the first.
    -- Errors use THROW (never ROLLBACK inside the trigger).
    IF EXISTS (SELECT 1
               FROM dbo.Users AS u
               WHERE u.Role = 'Student'
                 AND u.UserID IN (SELECT UserID FROM inserted)
                 AND (SELECT COUNT(*)
                      FROM dbo.Bookings AS b
                      WHERE b.UserID = u.UserID
                        AND b.Status = 'Active'
                        AND b.StartTime > SYSDATETIME()) > 3)
        THROW 50003, 'Students can have at most 3 upcoming bookings.', 1;
END;
GO

-- Runs after a room is edited. Refuses to lower the capacity below
-- the number of people in one of its upcoming bookings (protects rule 4).
CREATE OR ALTER TRIGGER dbo.trg_Rooms_CheckCapacity
ON dbo.Rooms
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS r
               JOIN dbo.Bookings AS b ON b.RoomID = r.RoomID
               WHERE b.Status = 'Active'
                 AND b.StartTime > SYSDATETIME()
                 AND b.People > r.Capacity)
        THROW 50008, 'This room has an upcoming booking with more people than the new capacity.', 1;
END;
GO
