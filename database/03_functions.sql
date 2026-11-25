-- =============================================================
-- 03_functions.sql
-- =============================================================
USE BookingDb;
GO

-- Returns one row per 30-minute slot between @Start and @End.
-- Example: 10:00 -> 11:00 gives 10:00 and 10:30.
CREATE OR ALTER FUNCTION dbo.fn_GetSlots (@Start datetime2(0), @End datetime2(0))
RETURNS TABLE
AS
RETURN
    SELECT DATEADD(MINUTE, 30 * n.n, @Start) AS SlotStart
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),(15)) AS n(n)
    WHERE DATEADD(MINUTE, 30 * n.n, @Start) < @End;
GO

-- Returns the units of one equipment type that are free between @Start and @End.
CREATE OR ALTER FUNCTION dbo.fn_FreeUnits (@EquipmentID int, @Start datetime2(0), @End datetime2(0))
RETURNS TABLE
AS
RETURN
    SELECT u.UnitID, u.SerialNumber
    FROM dbo.EquipmentUnits AS u
    WHERE u.EquipmentID = @EquipmentID
      AND NOT EXISTS (SELECT 1
                      FROM dbo.LoanSlots AS ls
                      WHERE ls.UnitID = u.UnitID
                        AND ls.SlotStart >= @Start
                        AND ls.SlotStart <  @End);
GO
