using BookingApi.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BookingApi.Controllers;

public record CreateBookingRequest(int RoomId, DateTime Start, DateTime End, int People, int? EquipmentId, int Quantity);

[ApiController]
[Authorize]
[Route("api/bookings")]
public class BookingsController : BaseController
{
    private readonly Db _db;
    public BookingsController(Db db) => _db = db;

    // GET /api/bookings/mine
    [HttpGet("mine")]
    public async Task<IActionResult> Mine() =>
        Ok(await _db.QueryAsync("dbo.sp_GetMyBookings", Db.Int("@UserID", CurrentUserId)));

    // POST /api/bookings   (the transaction is inside sp_CreateBooking)
    [HttpPost]
    public async Task<IActionResult> Create(CreateBookingRequest r)
    {
        var rows = await _db.QueryAsync("dbo.sp_CreateBooking",
            Db.Int("@UserID", CurrentUserId),
            Db.Int("@RoomID", r.RoomId),
            Db.When("@Start", r.Start),
            Db.When("@End", r.End),
            Db.SmallInt("@People", r.People),
            Db.Int("@EquipmentID", r.EquipmentId),
            Db.Int("@Quantity", r.Quantity));
        return Ok(rows.FirstOrDefault());
    }

    // POST /api/bookings/12/cancel
    [HttpPost("{bookingId:int}/cancel")]
    public async Task<IActionResult> Cancel(int bookingId)
    {
        await _db.ExecuteAsync("dbo.sp_CancelBooking",
            Db.Int("@BookingID", bookingId),
            Db.Int("@ActingUserID", CurrentUserId));
        return Ok(new { message = "Booking cancelled." });
    }
}
