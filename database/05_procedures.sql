-- =============================================================
-- 05_procedures.sql
-- The C# API only calls these procedures. It never writes SQL itself.
-- Error numbers 50001-50099 are our own errors; the API shows their message.
-- =============================================================
USE BookingDb;
GO

/* ------------------------------------------------------------
   ACCOUNTS
   ------------------------------------------------------------ */

-- Admin creates a new account. Receives the Argon2id hash, never the password.
CREATE OR ALTER PROCEDURE dbo.sp_RegisterUser
    @ActingUserID int,
    @FullName     nvarchar(100),
    @Email        varchar(254),
    @PasswordHash varchar(255),
    @Role         varchar(10)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserID = @ActingUserID AND Role = 'Admin')
        THROW 50020, 'Only admins can do this.', 1;

    INSERT INTO dbo.Users (FullName, Email, PasswordHash, Role)
    VALUES (@FullName, @Email, @PasswordHash, @Role);

    SELECT CAST(SCOPE_IDENTITY() AS int) AS UserID;
END;
GO

-- Returns what the API needs to check a password at login.
CREATE OR ALTER PROCEDURE dbo.sp_GetUserForLogin
    @Email varchar(254)
AS
BEGIN
    SET NOCOUNT ON;
    -- Email is returned masked (kXXX@XXXX.com) to booking_app - see 07_security.sql
    SELECT UserID, FullName, Email, Role, PasswordHash
    FROM dbo.Users
    WHERE Email = @Email;
END;
GO

-- Used once by the API's "--set-demo-passwords" command.
CREATE OR ALTER PROCEDURE dbo.sp_GetUsersWithoutPassword
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserID, Email FROM dbo.Users WHERE PasswordHash = 'NOT_SET';
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SetPasswordHash
    @UserID       int,
    @PasswordHash varchar(255)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Users SET PasswordHash = @PasswordHash WHERE UserID = @UserID;
END;
GO

/* ------------------------------------------------------------
   SEARCH
   ------------------------------------------------------------ */

-- Rooms free for a time window and number of people.
-- Students only see study rooms (rule 5).
CREATE OR ALTER PROCEDURE dbo.sp_FindFreeRooms
    @UserID int,
    @Start  datetime2(0),
    @End    datetime2(0),
    @People smallint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT r.RoomID, r.RoomName, r.RoomType, r.Capacity
    FROM dbo.Rooms AS r
    WHERE r.Capacity >= @People
      AND NOT EXISTS (SELECT 1
                      FROM dbo.BookingSlots AS s
                      WHERE s.RoomID = r.RoomID
                        AND s.SlotStart >= @Start
                        AND s.SlotStart <  @End)
      AND (r.RoomType = 'Study'
           OR EXISTS (SELECT 1 FROM dbo.Users WHERE UserID = @UserID AND Role IN ('Faculty', 'Admin')))
    ORDER BY r.RoomType DESC, r.Capacity, r.RoomName;
END;
GO

-- Each equipment type with its total and free units for a time window.
CREATE OR ALTER PROCEDURE dbo.sp_FindFreeEquipment
    @Start datetime2(0),
    @End   datetime2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.EquipmentID,
           e.Name,
           (SELECT COUNT(*) FROM dbo.EquipmentUnits AS u WHERE u.EquipmentID = e.EquipmentID) AS TotalUnits,
           (SELECT COUNT(*) FROM dbo.fn_FreeUnits(e.EquipmentID, @Start, @End))              AS FreeUnits
    FROM dbo.Equipment AS e
    ORDER BY e.Name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ListRooms
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RoomID, RoomName, RoomType, Capacity FROM dbo.Rooms ORDER BY RoomName;
END;
GO

/* ------------------------------------------------------------
   BOOKINGS
   ------------------------------------------------------------ */

-- THE TRANSACTION (design doc, section 8).
-- Changes 4 tables: Bookings, BookingSlots, EquipmentLoans, LoanSlots.
-- Either everything is saved, or nothing is.
CREATE OR ALTER PROCEDURE dbo.sp_CreateBooking
    @UserID      int,
    @RoomID      int,
    @Start       datetime2(0),
    @End         datetime2(0),
    @People      smallint,
    @EquipmentID int = NULL,   -- optional: which equipment type
    @Quantity    int = 0       -- optional: how many units
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- any error rolls back the whole transaction

    IF @Start <= SYSDATETIME()
        THROW 50009, 'You cannot book a time in the past.', 1;

    DECLARE @BookingID int;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Lock 1 (rule 3): lock this user's row until COMMIT.
        -- If the same student sends two bookings at the same second, the second
        -- request WAITS here until the first one commits. Then its trigger
        -- counts the first booking too, so both can never pass.
        DECLARE @Lock int;
        SELECT @Lock = UserID
        FROM dbo.Users WITH (UPDLOCK, HOLDLOCK)
        WHERE UserID = @UserID;

        -- Step 1: the booking. The trigger checks rules 3, 4 and 5.
        INSERT INTO dbo.Bookings (UserID, RoomID, StartTime, EndTime, People, Status)
        VALUES (@UserID, @RoomID, @Start, @End, @People, 'Active');
        SET @BookingID = SCOPE_IDENTITY();

        -- Step 2: its 30-minute slots. Fails if the room is taken (rule 6).
        INSERT INTO dbo.BookingSlots (RoomID, SlotStart, BookingID)
        SELECT @RoomID, SlotStart, @BookingID
        FROM dbo.fn_GetSlots(@Start, @End);

        IF @EquipmentID IS NOT NULL AND @Quantity > 0
        BEGIN
            -- Lock 2 (equipment): lock this equipment type until COMMIT.
            -- Two users who want the same type now take turns: the second one
            -- waits, then sees the units the first one took and picks another
            -- free unit, instead of choosing the same unit and getting an error.
            SELECT @Lock = EquipmentID
            FROM dbo.Equipment WITH (UPDLOCK, HOLDLOCK)
            WHERE EquipmentID = @EquipmentID;

            -- Step 3: pick free units and create the loans.
            DECLARE @Units TABLE (UnitID int);
            INSERT INTO @Units (UnitID)
            SELECT TOP (@Quantity) UnitID
            FROM dbo.fn_FreeUnits(@EquipmentID, @Start, @End)
            ORDER BY UnitID;

            IF (SELECT COUNT(*) FROM @Units) < @Quantity
                THROW 50007, 'Not enough units of this equipment are free at that time.', 1;

            DECLARE @Loans TABLE (LoanID int, UnitID int);
            INSERT INTO dbo.EquipmentLoans (BookingID, UnitID)
            OUTPUT inserted.LoanID, inserted.UnitID INTO @Loans (LoanID, UnitID)
            SELECT @BookingID, UnitID FROM @Units;

            -- Step 4: the units' slots. Fails if a unit is already lent (rule 7).
            INSERT INTO dbo.LoanSlots (UnitID, SlotStart, LoanID)
            SELECT l.UnitID, s.SlotStart, l.LoanID
            FROM @Loans AS l
            CROSS JOIN dbo.fn_GetSlots(@Start, @End) AS s;
        END

        -- Step 5
        COMMIT TRANSACTION;
        SELECT @BookingID AS BookingID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;   -- undo everything

        -- Turn duplicate-key errors into clear messages
        IF ERROR_NUMBER() = 2627 AND ERROR_MESSAGE() LIKE '%PK_BookingSlots%'
            THROW 50006, 'This room is already booked at that time.', 1;
        IF ERROR_NUMBER() = 2627 AND ERROR_MESSAGE() LIKE '%PK_LoanSlots%'
            THROW 50007, 'Not enough units of this equipment are free at that time.', 1;

        THROW;   -- any other error goes to the API as it is
    END CATCH
END;
GO

-- Rule 8: only the owner or an admin, and only before the booking starts.
CREATE OR ALTER PROCEDURE dbo.sp_CancelBooking
    @BookingID    int,
    @ActingUserID int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OwnerID int, @Start datetime2(0), @Status varchar(10);
    SELECT @OwnerID = UserID, @Start = StartTime, @Status = Status
    FROM dbo.Bookings WHERE BookingID = @BookingID;

    IF @OwnerID IS NULL
        THROW 50010, 'Booking not found.', 1;
    IF @OwnerID <> @ActingUserID
       AND NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserID = @ActingUserID AND Role = 'Admin')
        THROW 50011, 'You can only cancel your own bookings.', 1;
    IF @Status = 'Cancelled'
        THROW 50012, 'This booking is already cancelled.', 1;
    IF @Start <= SYSDATETIME()
        THROW 50013, 'A booking can only be cancelled before it starts.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Bookings SET Status = 'Cancelled' WHERE BookingID = @BookingID;

        -- free the equipment
        DELETE ls
        FROM dbo.LoanSlots AS ls
        JOIN dbo.EquipmentLoans AS l ON l.LoanID = ls.LoanID
        WHERE l.BookingID = @BookingID;

        -- free the room
        DELETE FROM dbo.BookingSlots WHERE BookingID = @BookingID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Query 1 (design doc, section 6): a user's upcoming ACTIVE bookings.
-- Covered by IX_Bookings_User (UserID, Status, StartTime) INCLUDE (RoomID, EndTime, People).
CREATE OR ALTER PROCEDURE dbo.sp_GetMyBookings
    @UserID int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT b.BookingID, r.RoomName, r.RoomType, b.StartTime, b.EndTime, b.People, b.Status,
           (SELECT STRING_AGG(CONCAT(e.Name, ' (', u.SerialNumber, ')'), ', ')
            FROM dbo.EquipmentLoans AS l
            JOIN dbo.EquipmentUnits AS u ON u.UnitID = l.UnitID
            JOIN dbo.Equipment      AS e ON e.EquipmentID = u.EquipmentID
            WHERE l.BookingID = b.BookingID) AS Equipment
    FROM dbo.Bookings AS b
    JOIN dbo.Rooms    AS r ON r.RoomID = b.RoomID
    WHERE b.UserID = @UserID
      AND b.Status = 'Active'
      AND b.StartTime >= SYSDATETIME()
    ORDER BY b.StartTime;
END;
GO

-- Query 2: one room's bookings for one day.
CREATE OR ALTER PROCEDURE dbo.sp_GetRoomSchedule
    @RoomID int,
    @Day    date
AS
BEGIN
    SET NOCOUNT ON;
    SELECT b.BookingID, u.FullName, b.StartTime, b.EndTime, b.People
    FROM dbo.Bookings AS b
    JOIN dbo.Users    AS u ON u.UserID = b.UserID
    WHERE b.RoomID = @RoomID
      AND b.StartTime >= @Day
      AND b.StartTime <  DATEADD(DAY, 1, @Day)
      AND b.Status = 'Active'
    ORDER BY b.StartTime;
END;
GO

-- Query 3: number of bookings per room for a period (admin report).
CREATE OR ALTER PROCEDURE dbo.sp_RoomReport
    @ActingUserID int,
    @From date,
    @To   date
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserID = @ActingUserID AND Role = 'Admin')
        THROW 50020, 'Only admins can do this.', 1;

    SELECT r.RoomID, r.RoomName, r.RoomType, ISNULL(x.TotalBookings, 0) AS TotalBookings
    FROM dbo.Rooms AS r
    LEFT JOIN (SELECT RoomID, COUNT(*) AS TotalBookings
               FROM dbo.Bookings
               WHERE StartTime >= @From
                 AND StartTime <  DATEADD(DAY, 1, @To)
                 AND Status = 'Active'
               GROUP BY RoomID) AS x ON x.RoomID = r.RoomID
    ORDER BY TotalBookings DESC, r.RoomName;
END;
GO

/* ------------------------------------------------------------
   ADMIN
   ------------------------------------------------------------ */

-- Adds a room (@RoomID = NULL) or edits one.
CREATE OR ALTER PROCEDURE dbo.sp_AddRoom
    @ActingUserID int,
    @RoomID       int = NULL,
    @RoomName     varchar(20),
    @RoomType     varchar(5),
    @Capacity     smallint
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserID = @ActingUserID AND Role = 'Admin')
        THROW 50020, 'Only admins can do this.', 1;

    IF @RoomID IS NULL
    BEGIN
        INSERT INTO dbo.Rooms (RoomName, RoomType, Capacity) VALUES (@RoomName, @RoomType, @Capacity);
        SELECT CAST(SCOPE_IDENTITY() AS int) AS RoomID;
    END
    ELSE
    BEGIN
        UPDATE dbo.Rooms   -- the trigger trg_Rooms_CheckCapacity protects rule 4
        SET RoomName = @RoomName, RoomType = @RoomType, Capacity = @Capacity
        WHERE RoomID = @RoomID;
        SELECT @RoomID AS RoomID;
    END
END;
GO

-- Adds one physical item. Creates the equipment type if it is new.
CREATE OR ALTER PROCEDURE dbo.sp_AddEquipmentUnit
    @ActingUserID  int,
    @EquipmentName nvarchar(80),
    @SerialNumber  varchar(40)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserID = @ActingUserID AND Role = 'Admin')
        THROW 50020, 'Only admins can do this.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Equipment WHERE Name = @EquipmentName)
        INSERT INTO dbo.Equipment (Name) VALUES (@EquipmentName);

    INSERT INTO dbo.EquipmentUnits (EquipmentID, SerialNumber)
    SELECT EquipmentID, @SerialNumber FROM dbo.Equipment WHERE Name = @EquipmentName;

    SELECT CAST(SCOPE_IDENTITY() AS int) AS UnitID;
END;
GO
