-- =============================================================
-- 00_run_all.sql
-- Rebuilds the whole database in one go.
--
-- In SSMS: open this file, turn on  Query > SQLCMD Mode,
-- set the path below to your "database" folder, then Execute (F5).
-- (Or simply open and run the scripts 01 to 09 one by one.)
-- =============================================================
:setvar folder "C:\booking-system\database"

:r $(folder)\01_create_database.sql
:r $(folder)\02_tables.sql
:r $(folder)\03_functions.sql
:r $(folder)\04_triggers.sql
:r $(folder)\05_procedures.sql
:r $(folder)\06_indexes.sql
:r $(folder)\07_security.sql
:r $(folder)\08_sample_data.sql
:r $(folder)\09_large_data.sql

-- Then:  cd api  ->  dotnet run -- --set-demo-passwords
-- Then run 10_tests.sql and 11_index_demo.sql
