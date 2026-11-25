-- =============================================================
-- 07_security.sql
-- Database logins and their rights (design doc, section 9).
--
-- IMPORTANT: SQL Server must allow "SQL Server and Windows
-- Authentication mode" (SSMS > right-click the server >
-- Properties > Security), then restart the SQL Server service.
--
-- Change both passwords below before running.
-- =============================================================
USE master;
GO

IF SUSER_ID('booking_app') IS NULL
    CREATE LOGIN booking_app   WITH PASSWORD = 'CHANGE_ME_App_2026!',   CHECK_POLICY = ON;
IF SUSER_ID('booking_admin') IS NULL
    CREATE LOGIN booking_admin WITH PASSWORD = 'CHANGE_ME_Admin_2026!', CHECK_POLICY = ON;
GO

USE BookingDb;
GO

-- booking_app: used by the C# API. Can ONLY execute procedures.
-- It has no SELECT, INSERT, UPDATE or DELETE right on any table.
-- The procedures can still use the tables because they have the same
-- owner (dbo) - this is called "ownership chaining".
CREATE USER booking_app FOR LOGIN booking_app;
CREATE ROLE app_executor;
GRANT EXECUTE ON SCHEMA::dbo TO app_executor;
ALTER ROLE app_executor ADD MEMBER booking_app;
GO

-- booking_admin: used by us to create tables and load data. Never used by the app.
CREATE USER booking_admin FOR LOGIN booking_admin;
ALTER ROLE db_owner ADD MEMBER booking_admin;
GO

-- Email masking (Dynamic Data Masking).
-- Any login WITHOUT the UNMASK right (booking_app) only sees "kXXX@XXXX.com".
-- booking_admin is db_owner, so it still sees the real e-mails.
-- Searching still works on the real value: sp_GetUserForLogin can still
-- find a user WHERE Email = @Email, it just cannot read the e-mail back.
ALTER TABLE dbo.Users ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
GO

-- Note: the UserID of the person acting is never sent by React.
-- The C# API reads it from the signed login token (BaseController.CurrentUserId)
-- and passes it to the procedures.

-- ---------- Checks you can show the doctor ----------
-- 1) booking_app cannot read tables: FAILS with "The SELECT permission was denied"
-- EXECUTE AS USER = 'booking_app';
-- SELECT * FROM dbo.Users;
-- REVERT;

-- 2) booking_app sees masked e-mails: shows kXXX@XXXX.com
-- EXECUTE AS USER = 'booking_app';
-- EXEC dbo.sp_GetUserForLogin @Email = 'karl@uni.edu';
-- REVERT;
