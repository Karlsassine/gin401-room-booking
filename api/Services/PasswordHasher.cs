using System.Security.Cryptography;
using System.Text;
using Konscious.Security.Cryptography;

namespace BookingApi.Services;

/// <summary>
/// Hashes passwords with Argon2id (OWASP minimum: 19 MiB memory, 2 iterations, 1 thread).
/// Stored format:  $argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>
/// </summary>
public static class PasswordHasher
{
    private const int MemoryKb = 19456;  // 19 MiB
    private const int Iterations = 2;
    private const int Parallelism = 1;
    private const int SaltBytes = 16;
    private const int HashBytes = 32;

    public static string Hash(string password)
    {
        byte[] salt = RandomNumberGenerator.GetBytes(SaltBytes);   // a new random salt for every user
        byte[] hash = Compute(password, salt, MemoryKb, Iterations, Parallelism);
        return $"$argon2id$v=19$m={MemoryKb},t={Iterations},p={Parallelism}${ToB64(salt)}${ToB64(hash)}";
    }

    public static bool Verify(string password, string stored)
    {
        try
        {
            // ["", "argon2id", "v=19", "m=19456,t=2,p=1", salt, hash]
            string[] parts = stored.Split('$');
            if (parts.Length != 6 || parts[1] != "argon2id") return false;

            var settings = parts[3].Split(',')
                .Select(p => p.Split('='))
                .ToDictionary(kv => kv[0], kv => int.Parse(kv[1]));

            byte[] salt = FromB64(parts[4]);
            byte[] expected = FromB64(parts[5]);
            byte[] actual = Compute(password, salt, settings["m"], settings["t"], settings["p"]);

            // constant-time comparison
            return CryptographicOperations.FixedTimeEquals(actual, expected);
        }
        catch
        {
            return false;   // e.g. 'NOT_SET' or a damaged hash
        }
    }

    private static byte[] Compute(string password, byte[] salt, int memoryKb, int iterations, int parallelism)
    {
        using var argon2 = new Argon2id(Encoding.UTF8.GetBytes(password))
        {
            Salt = salt,
            MemorySize = memoryKb,
            Iterations = iterations,
            DegreeOfParallelism = parallelism
        };
        return argon2.GetBytes(HashBytes);
    }

    private static string ToB64(byte[] bytes) => Convert.ToBase64String(bytes).TrimEnd('=');

    private static byte[] FromB64(string text) =>
        Convert.FromBase64String(text.PadRight(text.Length + (4 - text.Length % 4) % 4, '='));
}
