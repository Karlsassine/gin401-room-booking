-- =============================================================
-- 01_create_database.sql
-- Creates an empty BookingDb database (drops the old one first).
-- Run this as booking_admin or as your Windows admin account.
-- =============================================================
USE master;
GO

IF DB_ID('BookingDb') IS NOT NULL
BEGIN
    ALTER DATABASE BookingDb SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BookingDb;
END
GO

CREATE DATABASE BookingDb;
GO
