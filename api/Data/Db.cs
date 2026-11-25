using System.Data;
using Microsoft.Data.SqlClient;

namespace BookingApi.Data;

/// <summary>
/// The only class that talks to SQL Server (ADO.NET).
/// It always calls a stored procedure, never a SQL string.
/// </summary>
public class Db
{
    private readonly string _connectionString;

    public Db(IConfiguration config)
    {
        // Kept in User Secrets (development) or an environment variable (server).
        _connectionString = config.GetConnectionString("BookingDb")
            ?? throw new InvalidOperationException(
                "Connection string 'BookingDb' is missing. Set it with: dotnet user-secrets set \"ConnectionStrings:BookingDb\" \"...\"");
    }

    /// <summary>Runs a stored procedure and returns its rows.</summary>
    public async Task<List<Dictionary<string, object?>>> QueryAsync(string procedure, params SqlParameter[] parameters)
    {
        var rows = new List<Dictionary<string, object?>>();

        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand(procedure, connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var row = new Dictionary<string, object?>();
            for (int i = 0; i < reader.FieldCount; i++)
                row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
            rows.Add(row);
        }
        return rows;
    }

    /// <summary>Runs a stored procedure that returns nothing.</summary>
    public async Task ExecuteAsync(string procedure, params SqlParameter[] parameters)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = new SqlCommand(procedure, connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);
        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    // Small helpers to create typed parameters
    public static SqlParameter Int(string name, int? value) =>
        new(name, SqlDbType.Int) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter SmallInt(string name, int value) =>
        new(name, SqlDbType.SmallInt) { Value = (short)value };

    public static SqlParameter Text(string name, string? value, int size) =>
        new(name, SqlDbType.NVarChar, size) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter When(string name, DateTime value) =>
        new(name, SqlDbType.DateTime2) { Value = value, Scale = 0 };

    public static SqlParameter Day(string name, DateTime value) =>
        new(name, SqlDbType.Date) { Value = value.Date };
}
