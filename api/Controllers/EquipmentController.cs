using BookingApi.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BookingApi.Controllers;

[ApiController]
[Authorize]
[Route("api/equipment")]
public class EquipmentController : BaseController
{
    private readonly Db _db;
    public EquipmentController(Db db) => _db = db;

    // GET /api/equipment/free?start=2026-11-25T10:00&end=2026-11-25T11:00
    [HttpGet("free")]
    public async Task<IActionResult> Free(DateTime start, DateTime end) =>
        Ok(await _db.QueryAsync("dbo.sp_FindFreeEquipment",
            Db.When("@Start", start),
            Db.When("@End", end)));
}
