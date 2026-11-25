-- =============================================================
-- 08_sample_data.sql
-- Users, rooms and equipment.
--
-- Passwords are 'NOT_SET' here, because only the C# API can make
-- Argon2id hashes. After running this script, run once:
--     cd api
--     dotnet run -- --set-demo-passwords
-- That gives every user the password:  Password123!
-- =============================================================
USE BookingDb;
GO

-- ---------- Demo accounts (use these to log in) ----------
INSERT INTO dbo.Users (FullName, Email, PasswordHash, Role) VALUES
 (N'Admin Office',          'admin@uni.edu',       'NOT_SET', 'Admin'),
 (N'Dr. Bruno',             'bruno@uni.edu',       'NOT_SET', 'Faculty'),
 (N'Karl Sassine',          'karl@uni.edu',        'NOT_SET', 'Student'),
 (N'Jean Michel Outayek',   'jeanmichel@uni.edu',  'NOT_SET', 'Student'),
 (N'Sara Haddad',           'sara@uni.edu',        'NOT_SET', 'Student');
GO

-- ---------- 200 more students and 20 more faculty (for the large data) ----------
;WITH n AS (SELECT TOP (200) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects)
INSERT INTO dbo.Users (FullName, Email, PasswordHash, Role)
SELECT CONCAT(N'Student ', i),
       CONCAT('student', RIGHT('000' + CAST(i AS varchar(3)), 3), '@uni.edu'),
       'NOT_SET', 'Student'
FROM n;

;WITH n AS (SELECT TOP (20) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects)
INSERT INTO dbo.Users (FullName, Email, PasswordHash, Role)
SELECT CONCAT(N'Faculty ', i),
       CONCAT('faculty', RIGHT('00' + CAST(i AS varchar(2)), 2), '@uni.edu'),
       'NOT_SET', 'Faculty'
FROM n;
GO

-- ---------- 24 study rooms (S-101 ... S-124) and 6 labs (LAB-1 ... LAB-6) ----------
;WITH n AS (SELECT TOP (24) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects)
INSERT INTO dbo.Rooms (RoomName, RoomType, Capacity)
SELECT CONCAT('S-', 100 + i), 'Study', 4 + (i % 4) * 2      -- capacity 4, 6, 8 or 10
FROM n;

;WITH n AS (SELECT TOP (6) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects)
INSERT INTO dbo.Rooms (RoomName, RoomType, Capacity)
SELECT CONCAT('LAB-', i), 'Lab', 20 + (i % 3) * 5           -- capacity 20, 25 or 30
FROM n;
GO

-- ---------- Equipment types and their units ----------
INSERT INTO dbo.Equipment (Name) VALUES (N'Laptop'), (N'Projector'), (N'Oscilloscope'), (N'Arduino Kit');

;WITH n AS (SELECT TOP (10) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects),
      t AS (SELECT * FROM (VALUES (N'Laptop', 'LAP', 10), (N'Projector', 'PRJ', 3),
                                  (N'Oscilloscope', 'OSC', 5), (N'Arduino Kit', 'ARD', 8)) v(Name, Prefix, Units))
INSERT INTO dbo.EquipmentUnits (EquipmentID, SerialNumber)
SELECT e.EquipmentID, CONCAT(t.Prefix, '-', RIGHT('00' + CAST(n.i AS varchar(2)), 2))
FROM t
JOIN dbo.Equipment AS e ON e.Name = t.Name
JOIN n ON n.i <= t.Units;
GO

SELECT (SELECT COUNT(*) FROM dbo.Users) AS Users,
       (SELECT COUNT(*) FROM dbo.Rooms) AS Rooms,
       (SELECT COUNT(*) FROM dbo.EquipmentUnits) AS EquipmentUnits;
