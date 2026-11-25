using Microsoft.Data.SqlClient;

namespace BookingApi.Services;

/// <summary>Turns a SQL Server error into a message the user understands.</summary>
public static class SqlErrors
{
    // CHECK and UNIQUE constraint names from 02_tables.sql
    private static readonly Dictionary<string, string> Messages = new()
    {
        ["CK_Bookings_Hours"]    = "Bookings are only allowed between 08:00 and 16:00.",
        ["CK_Bookings_Length"]   = "A booking must last between 30 minutes and 2 hours.",
        ["CK_Bookings_HalfHour"] = "Bookings must start and end on :00 or :30.",
        ["CK_Bookings_Order"]    = "The end time must be after the start time.",
        ["CK_Bookings_SameDay"]  = "A booking must start and end on the same day.",
        ["CK_Bookings_People"]   = "The number of people must be at least 1.",
        ["CK_Rooms_Capacity"]    = "Capacity must be more than 0.",
        ["CK_Rooms_Type"]        = "Room type must be Study or Lab.",
        ["CK_Users_Role"]        = "Role must be Student, Faculty or Admin.",
        ["CK_Users_Email"]       = "This e-mail address is not valid.",
        ["UQ_Users_Email"]       = "This e-mail is already registered.",
        ["UQ_Rooms_Name"]        = "A room with this name already exists.",
        ["UQ_EquipmentUnits_Serial"] = "A unit with this serial number already exists.",
    };

    public static string ToMessage(SqlException ex)
    {
        // Our own errors (THROW 50001 - 50099) already have a clear message
        if (ex.Number >= 50000) return ex.Message;

        foreach (var (constraint, message) in Messages)
            if (ex.Message.Contains(constraint)) return message;

        return "The database refused this request.";
    }
}
