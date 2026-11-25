using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;

namespace BookingApi.Controllers;

public abstract class BaseController : ControllerBase
{
    /// <summary>
    /// The logged-in user's ID, read from the signed token.
    /// Never taken from the request body, so nobody can act as someone else.
    /// </summary>
    protected int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
