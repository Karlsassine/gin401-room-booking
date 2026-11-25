using BookingApi.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BookingApi.Controllers;

[ApiController]
[Authorize]
[Route("api/rooms")]
public class RoomsController : BaseController
{
    private readonly Db _db;
    public RoomsController(Db db) => _db = db;

    // GET /api/rooms
    [HttpGet]
    public async Task<IActionResult> All() =>
        Ok(await _db.QueryAsync("dbo.sp_ListRooms"));

    // GET /api/rooms/free?start=2026-11-25T10:00&end=2026-11-25T11:00&people=3
    [HttpGet("free")]
    public async Task<IActionResult> Free(DateTime start, DateTime end, int people) =>
        Ok(await _db.QueryAsync("dbo.sp_FindFreeRooms",
            Db.Int("@UserID", CurrentUserId),
            Db.When("@Start", start),
            Db.When("@End", end),
            Db.SmallInt("@People", people)));

    // GET /api/rooms/5/schedule?day=2026-11-25
    [HttpGet("{roomId:int}/schedule")]
    public async Task<IActionResult> Schedule(int roomId, DateTime day) =>
        Ok(await _db.QueryAsync("dbo.sp_GetRoomSchedule",
            Db.Int("@RoomID", roomId),
            Db.Day("@Day", day)));
}
