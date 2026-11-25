-- =============================================================
-- 02_tables.sql
-- The 8 tables with their primary keys, foreign keys,
-- UNIQUE and CHECK constraints (design doc, sections 2 and 3).
-- =============================================================
USE BookingDb;
GO

-- ---------- Users ----------
CREATE TABLE dbo.Users (
    UserID        int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
    FullName      nvarchar(100)     NOT NULL,
    Email         varchar(254)      NOT NULL CONSTRAINT UQ_Users_Email UNIQUE,
    PasswordHash  varchar(255)      NOT NULL,   -- Argon2id hash, never the password
    Role          varchar(10)       NOT NULL,
    CONSTRAINT CK_Users_Role  CHECK (Role IN ('Student', 'Faculty', 'Admin')),
    CONSTRAINT CK_Users_Email CHECK (Email LIKE '%_@_%._%')
);
GO

-- ---------- Rooms ----------
CREATE TABLE dbo.Rooms (
    RoomID    int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Rooms PRIMARY KEY,
    RoomName  varchar(20)       NOT NULL CONSTRAINT UQ_Rooms_Name UNIQUE,
    RoomType  varchar(5)        NOT NULL,
    Capacity  smallint          NOT NULL,
    CONSTRAINT CK_Rooms_Type     CHECK (RoomType IN ('Study', 'Lab')),
    CONSTRAINT CK_Rooms_Capacity CHECK (Capacity > 0)
);
GO

-- ---------- Bookings (the large table) ----------
CREATE TABLE dbo.Bookings (
    BookingID  int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Bookings PRIMARY KEY,
    UserID     int               NOT NULL CONSTRAINT FK_Bookings_Users REFERENCES dbo.Users(UserID),
    RoomID     int               NOT NULL CONSTRAINT FK_Bookings_Rooms REFERENCES dbo.Rooms(RoomID),
    StartTime  datetime2(0)      NOT NULL,
    EndTime    datetime2(0)      NOT NULL,
    People     smallint          NOT NULL,
    Status     varchar(10)       NOT NULL CONSTRAINT DF_Bookings_Status DEFAULT ('Active'),
    CreatedAt  datetime2(0)      NOT NULL CONSTRAINT DF_Bookings_CreatedAt DEFAULT (SYSDATETIME()),

    -- end after start, on the same day
    CONSTRAINT CK_Bookings_Order   CHECK (EndTime > StartTime),
    CONSTRAINT CK_Bookings_SameDay CHECK (CAST(StartTime AS date) = CAST(EndTime AS date)),
    -- Rule 1: opening hours 08:00 - 16:00
    CONSTRAINT CK_Bookings_Hours   CHECK (CAST(StartTime AS time) >= '08:00' AND CAST(EndTime AS time) <= '16:00'),
    -- Rule 2: 30 minutes to 2 hours, on :00 or :30
    CONSTRAINT CK_Bookings_Length  CHECK (DATEDIFF(MINUTE, StartTime, EndTime) BETWEEN 30 AND 120),
    CONSTRAINT CK_Bookings_HalfHour CHECK (DATEPART(MINUTE, StartTime) IN (0, 30) AND DATEPART(SECOND, StartTime) = 0
                                       AND DATEPART(MINUTE, EndTime)   IN (0, 30) AND DATEPART(SECOND, EndTime)   = 0),
    CONSTRAINT CK_Bookings_People  CHECK (People > 0),
    CONSTRAINT CK_Bookings_Status  CHECK (Status IN ('Active', 'Cancelled')),
    -- needed so that BookingSlots can point to (BookingID, RoomID) together
    CONSTRAINT UQ_Bookings_BookingRoom UNIQUE (BookingID, RoomID)
);
GO

-- ---------- BookingSlots (rule 6: no double booking) ----------
-- One row per 30 minutes of a booking. The primary key (RoomID, SlotStart)
-- can never repeat, so a room can never be booked twice for the same half hour.
-- The composite foreign key (BookingID, RoomID) forces the slot's room
-- to be the same as its booking's room.
CREATE TABLE dbo.BookingSlots (
    RoomID     int          NOT NULL,
    SlotStart  datetime2(0) NOT NULL,
    BookingID  int          NOT NULL,
    CONSTRAINT PK_BookingSlots PRIMARY KEY (RoomID, SlotStart),
    CONSTRAINT FK_BookingSlots_Bookings FOREIGN KEY (BookingID, RoomID)
        REFERENCES dbo.Bookings (BookingID, RoomID),
    CONSTRAINT CK_BookingSlots_HalfHour CHECK (DATEPART(MINUTE, SlotStart) IN (0, 30) AND DATEPART(SECOND, SlotStart) = 0)
);
GO

-- ---------- Equipment (types, e.g. "Oscilloscope") ----------
CREATE TABLE dbo.Equipment (
    EquipmentID  int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Equipment PRIMARY KEY,
    Name         nvarchar(80)      NOT NULL CONSTRAINT UQ_Equipment_Name UNIQUE
);
GO

-- ---------- EquipmentUnits (one row per physical item) ----------
CREATE TABLE dbo.EquipmentUnits (
    UnitID        int IDENTITY(1,1) NOT NULL CONSTRAINT PK_EquipmentUnits PRIMARY KEY,
    EquipmentID   int               NOT NULL CONSTRAINT FK_EquipmentUnits_Equipment REFERENCES dbo.Equipment(EquipmentID),
    SerialNumber  varchar(40)       NOT NULL CONSTRAINT UQ_EquipmentUnits_Serial UNIQUE
);
GO

-- ---------- EquipmentLoans (one unit lent with one booking) ----------
CREATE TABLE dbo.EquipmentLoans (
    LoanID     int IDENTITY(1,1) NOT NULL CONSTRAINT PK_EquipmentLoans PRIMARY KEY,
    BookingID  int               NOT NULL CONSTRAINT FK_EquipmentLoans_Bookings REFERENCES dbo.Bookings(BookingID),
    UnitID     int               NOT NULL CONSTRAINT FK_EquipmentLoans_Units    REFERENCES dbo.EquipmentUnits(UnitID),
    CONSTRAINT UQ_EquipmentLoans UNIQUE (BookingID, UnitID),
    -- needed so that LoanSlots can point to (LoanID, UnitID) together
    CONSTRAINT UQ_EquipmentLoans_LoanUnit UNIQUE (LoanID, UnitID)
);
GO

-- ---------- LoanSlots (rule 7: never lend more units than we have) ----------
-- One row per 30 minutes of a loan. The primary key (UnitID, SlotStart)
-- means one unit can never be lent twice at the same time.
-- The composite foreign key (LoanID, UnitID) forces the slot's unit
-- to be the same as its loan's unit.
CREATE TABLE dbo.LoanSlots (
    UnitID     int          NOT NULL,
    SlotStart  datetime2(0) NOT NULL,
    LoanID     int          NOT NULL,
    CONSTRAINT PK_LoanSlots PRIMARY KEY (UnitID, SlotStart),
    CONSTRAINT FK_LoanSlots_Loans FOREIGN KEY (LoanID, UnitID)
        REFERENCES dbo.EquipmentLoans (LoanID, UnitID),
    CONSTRAINT CK_LoanSlots_HalfHour CHECK (DATEPART(MINUTE, SlotStart) IN (0, 30) AND DATEPART(SECOND, SlotStart) = 0)
);
GO
