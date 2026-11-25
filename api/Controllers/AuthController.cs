using BookingApi.Data;
using BookingApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace BookingApi.Controllers;

public record LoginRequest(string Email, string Password);

[ApiController]
[Route("api/auth")]
public class AuthController : BaseController
{
    private readonly Db _db;
    private readonly TokenService _tokens;

    public AuthController(Db db, TokenService tokens)
    {
        _db = db;
        _tokens = tokens;
    }

    // POST /api/auth/login
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest request)
    {
        var rows = await _db.QueryAsync("dbo.sp_GetUserForLogin",
            Db.Text("@Email", request.Email.Trim(), 254));

        // Same message whether the e-mail or the password is wrong
        if (rows.Count == 0 || !PasswordHasher.Verify(request.Password, (string)rows[0]["PasswordHash"]!))
            return Unauthorized(new { error = "Wrong e-mail or password." });

        var user = rows[0];
        int userId = (int)user["UserID"]!;
        string fullName = (string)user["FullName"]!;
        string role = (string)user["Role"]!;

        return Ok(new
        {
            token = _tokens.CreateToken(userId, fullName, role),
            userId,
            fullName,
            role
        });
    }
}
