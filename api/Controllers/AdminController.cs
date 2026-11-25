using BookingApi.Data;
using BookingApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BookingApi.Controllers;

public record CreateUserRequest(string FullName, string Email, string Password, string Role);
public record SaveRoomRequest(int? RoomId, string RoomName, string RoomType, int Capacity);
public record AddUnitRequest(string EquipmentName, string SerialNumber);

// Only admins get in here. The procedures check the role again.
[ApiController]
[Authorize(Roles = "Admin")]
[Route("api/admin")]
public class AdminController : BaseController
{
    private readonly Db _db;
    public AdminController(Db db) => _db = db;

    // POST /api/admin/users
    [HttpPost("users")]
    public async Task<IActionResult> CreateUser(CreateUserRequest r)
    {
        if (string.IsNullOrWhiteSpace(r.Password) || r.Password.Length < 8)
            return BadRequest(new { error = "The password must have at least 8 characters." });

        var rows = await _db.QueryAsync("dbo.sp_RegisterUser",
            Db.Int("@ActingUserID", CurrentUserId),
            Db.Text("@FullName", r.FullName, 100),
            Db.Text("@Email", r.Email.Trim(), 254),
            Db.Text("@PasswordHash", PasswordHasher.Hash(r.Password), 255),   // only the hash goes to SQL
            Db.Text("@Role", r.Role, 10));
        return Ok(rows.FirstOrDefault());
    }

    // POST /api/admin/rooms   (RoomId = null adds a room, otherwise edits it)
    [HttpPost("rooms")]
    public async Task<IActionResult> SaveRoom(SaveRoomRequest r)
    {
        var rows = await _db.QueryAsync("dbo.sp_AddRoom",
            Db.Int("@ActingUserID", CurrentUserId),
            Db.Int("@RoomID", r.RoomId),
            Db.Text("@RoomName", r.RoomName, 20),
            Db.Text("@RoomType", r.RoomType, 5),
            Db.SmallInt("@Capacity", r.Capacity));
        return Ok(rows.FirstOrDefault());
    }

    // POST /api/admin/equipment
    [HttpPost("equipment")]
    public async Task<IActionResult> AddUnit(AddUnitRequest r)
    {
        var rows = await _db.QueryAsync("dbo.sp_AddEquipmentUnit",
            Db.Int("@ActingUserID", CurrentUserId),
            Db.Text("@EquipmentName", r.EquipmentName, 80),
            Db.Text("@SerialNumber", r.SerialNumber, 40));
        return Ok(rows.FirstOrDefault());
    }

    // GET /api/admin/report?from=2026-10-01&to=2026-10-31
    [HttpGet("report")]
    public async Task<IActionResult> Report(DateTime from, DateTime to) =>
        Ok(await _db.QueryAsync("dbo.sp_RoomReport",
            Db.Int("@ActingUserID", CurrentUserId),
            Db.Day("@From", from),
            Db.Day("@To", to)));
}
