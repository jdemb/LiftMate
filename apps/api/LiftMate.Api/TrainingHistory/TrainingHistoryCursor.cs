using System.Globalization;
using System.Text;

namespace LiftMate.Api.TrainingHistory;

public readonly record struct TrainingHistoryCursor(DateTimeOffset CompletedAt, Guid SessionId)
{
    public string Encode()
    {
        var value = string.Create(
            CultureInfo.InvariantCulture,
            $"{CompletedAt.UtcTicks}|{SessionId:D}");
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(value))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    public static bool TryDecode(string? value, out TrainingHistoryCursor cursor)
    {
        cursor = default;
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        try
        {
            var normalized = value.Replace('-', '+').Replace('_', '/');
            normalized = normalized.PadRight(normalized.Length + ((4 - normalized.Length % 4) % 4), '=');
            var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(normalized));
            var parts = decoded.Split('|', StringSplitOptions.TrimEntries);
            if (parts.Length != 2 ||
                !long.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out var ticks) ||
                !Guid.TryParseExact(parts[1], "D", out var sessionId))
            {
                return false;
            }

            cursor = new TrainingHistoryCursor(new DateTimeOffset(ticks, TimeSpan.Zero), sessionId);
            return true;
        }
        catch (FormatException)
        {
            return false;
        }
        catch (ArgumentOutOfRangeException)
        {
            return false;
        }
    }
}
