# Campus Study Room & Lab Booking System — GIN401

React frontend → C# ASP.NET Core Web API (ADO.NET) → SQL Server.

```
booking-system/
  database/   SQL scripts 00–11 (run in order)
  api/        C# Web API
  web/        React app (Vite)
```

---

## 0. Install (once)

| Tool | Link / note |
| --- | --- |
| SQL Server 2022 **Developer** (free) | During install choose **Mixed Mode** authentication (SQL + Windows) |
| SSMS (SQL Server Management Studio) | To run the scripts |
| .NET 8 SDK | `dotnet --version` should show 8.x |
| Node.js LTS | `node -v` should show 18 or newer |

If SQL Server is already installed with Windows authentication only:
SSMS → right-click the server → Properties → Security → "SQL Server and Windows Authentication mode" → OK → restart the SQL Server service.

---

## 1. Database (about 5 minutes)

1. Open SSMS and connect with your Windows account.
2. Open `database/07_security.sql` and change the two passwords (`App_ChangeMe_2026!`, `Admin_ChangeMe_2026!`).
3. Run the scripts **in order**: `01` → `02` → `03` → `04` → `05` → `06` → `07` → `08` → `09`.
   (Or open `00_run_all.sql`, turn on *Query → SQLCMD Mode*, fix the folder path, press F5.)
4. `09_large_data.sql` takes about a minute. At the end it shows ~150,000 bookings.

---

## 2. API

Open a terminal in the `api` folder:

```bash
# 1) Connection string — kept in User Secrets, NOT in the code or GitHub
dotnet user-secrets set "ConnectionStrings:BookingDb" "Server=localhost;Database=BookingDb;User Id=booking_app;Password=App_ChangeMe_2026!;Encrypt=True;TrustServerCertificate=True"

# 2) Secret key for login tokens (any random text, at least 32 characters)
dotnet user-secrets set "Jwt:Key" "put-a-long-random-secret-here-1234567890"

# 3) Give every user the demo password Password123!  (run once)
dotnet run -- --set-demo-passwords

# 4) Start the API
dotnet run
```

- If your SQL Server is a named instance, use `Server=localhost\SQLEXPRESS` (or the name shown in SSMS).
- `TrustServerCertificate=True` is only for your laptop, because a local SQL Server uses a self-signed certificate.
- Swagger (to test the API without React): http://localhost:5000/swagger
  Call `POST /api/auth/login`, copy the `token`, click **Authorize**, paste it.

---

## 3. React

Open a **second** terminal in the `web` folder:

```bash
npm install
npm run dev
```

Open http://localhost:5173 and log in.

| Account | Role | Password |
| --- | --- | --- |
| admin@uni.edu | Admin | Password123! |
| bruno@uni.edu | Faculty | Password123! |
| karl@uni.edu | Student | Password123! |
| jeanmichel@uni.edu | Student | Password123! |
| sara@uni.edu | Student | Password123! |

---

## 4. Proof for the doctor

| What to show | How |
| --- | --- |
| Every rule is enforced by the database | Run `database/10_tests.sql`, open the **Messages** tab: every line should say PASS. |
| Covering indexes on the large table | Press Ctrl+M in SSMS, run `database/11_index_demo.sql`. Write the *logical reads* into the table at the top of the script, and screenshot *Scan* (before) vs *Seek* with no *Key Lookup* (after). |
| Two requests at the same second (rule 3 + equipment) | Open `12a_concurrency_window1.sql` and `12b_concurrency_window2.sql` in two SSMS windows. Run 12a, then 12b within 15 seconds. 12b waits, then: Sara's 4th booking is refused, and the admin gets a *different* free projector. Then run `12c_concurrency_cleanup.sql`. |
| The app user cannot touch tables | Uncomment check 1 at the end of `07_security.sql` and run it: "SELECT permission was denied". |
| E-mails are masked for the app | Uncomment check 2 at the end of `07_security.sql`: the e-mail shows as `kXXX@XXXX.com`. |
| Transaction rollback | Test "Transaction: a failed booking leaves nothing behind" in `10_tests.sql`. |
| Passwords are hashed | `SELECT Email, PasswordHash FROM Users` → every hash starts with `$argon2id$`. |

---

## Where each part of the design document is

| Design doc section | File |
| --- | --- |
| 2. Business rules | `02_tables.sql` (CHECKs), `04_triggers.sql`, `05_procedures.sql` |
| 3. Data model | `02_tables.sql` |
| 4. No double booking | `PK_BookingSlots`, `PK_LoanSlots` in `02_tables.sql` |
| 6. Large table + indexes | `09_large_data.sql`, `06_indexes.sql`, `11_index_demo.sql` |
| 7. Procedures, functions, triggers | `05_procedures.sql`, `03_functions.sql`, `04_triggers.sql` |
| 8. Transaction | `sp_CreateBooking` in `05_procedures.sql` |
| 9. Security | `07_security.sql`, `api/Services/PasswordHasher.cs`, User Secrets |

---

## Common problems

| Problem | Fix |
| --- | --- |
| `Login failed for user 'booking_app'` | Mixed Mode is off (see step 0), or the password in the connection string differs from `07_security.sql`. |
| `A network-related or instance-specific error` | Wrong server name. Use the name you see in SSMS when you connect. |
| `Connection string 'BookingDb' is missing` | Run the `dotnet user-secrets set` commands inside the `api` folder. |
| Login says "Wrong e-mail or password" for demo accounts | You skipped `dotnet run -- --set-demo-passwords`. |
| React shows "Request failed" everywhere | The API is not running. Start `dotnet run` in `api` first. |
