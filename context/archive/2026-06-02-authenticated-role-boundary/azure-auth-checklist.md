# Auth Boundary Azure Manual Gate

This checklist is for the human-run deployment gate in Phase 6. Do not paste secret values into this file.

## Required App Service Configuration

- `ConnectionStrings__DefaultConnection` or the equivalent App Service connection-string setting points to the Azure SQL database.
- `Jwt__Issuer` matches the deployed API issuer.
- `Jwt__Audience` matches the Flutter/API audience.
- `Jwt__SigningKey` is a strong secret supplied through App Service configuration.
- `Jwt__AccessTokenMinutes` is set to the intended MVP lifetime.
- `Jwt__RefreshTokenDays` is set to the intended MVP lifetime.
- `Auth__RegistrationInviteCode` is set through App Service configuration.

## Required Azure SQL Gate

- Azure SQL Database exists for the MVP/dev API.
- App Service networking/firewall rules allow the API to reach the database.
- The initial auth migration is applied only after the configuration above is present.
- No connection strings, JWT keys, invite codes, passwords, or refresh tokens are committed to source.

## Manual Verification

- Deployed API accepts registration with the configured invite code.
- Deployed API rejects registration with an invalid invite code.
- Deployed API login returns an access token and refresh token.
- `GET /auth/me` succeeds with a valid bearer token.
- Trainer token succeeds on `/trainer/probe` and is denied by `/trainee/probe`.
- Trainee token succeeds on `/trainee/probe` and is denied by `/trainer/probe`.
- Refresh returns a new token pair.
- Logout clears the server-side refresh token session.
- Flutter app can register, login, probe, restart with stored tokens, and logout against the deployed API.

## Rollback Note

Before applying the Azure migration, rollback is a code redeploy. After applying the migration, rollback requires redeploying the previous API build and deciding whether to keep the auth tables. Do not drop auth tables automatically because that would destroy registered MVP accounts.
