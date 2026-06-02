# LiftMate API Deploy Plan

Updated: 2026-05-26

## Summary

LiftMate Web API is deployed from branch `deploy-2026-05-26` to Azure App Service Free F1. The target app is:

- Resource group: `rg-liftmate-dev`
- App Service plan: `asp-liftmate-free-pl`
- Web App: `liftmate-api-dev-jdemb`
- Public URL: `https://liftmate-api-dev-jdemb.azurewebsites.net`
- Runtime: `dotnet:10`
- Deployment branch: `deploy-2026-05-26`

The original target region was `polandcentral`, but App Service Free F1 failed there with Azure stamp allocation errors. The active App Service plan is in `westeurope`.

## Implemented Changes

- Added `GET /health`, returning `{"status":"ok"}`.
- Kept Swagger/OpenAPI public for the prototype smoke/debug surface.
- Added GitHub Actions workflow at `.github/workflows/deploy-api-azure.yml`.
- Configured GitHub Actions OIDC deployment for `jdemb/PrototypApka` on branch `deploy-2026-05-26`.
- Did not add Azure SQL, EF Core, SignalR, realtime, or database connection strings in this deployment.

## Git State

Deployment branch:

```powershell
deploy-2026-05-26
```

Deployment commits:

```text
daf1261 api: prepare Azure smoke deploy
1f52a8c api: add Azure deploy workflow
1303550 api: rerun Azure deploy
```

`1303550` is an empty rerun commit. It did not trigger a new workflow because the workflow has a `paths:` filter. The successful GitHub Actions deploy is a rerun of workflow run `26463346629` at commit `1f52a8c`.

## Azure OIDC Configuration

Azure app registration:

- Client ID: `5728510f-6be6-4da5-8ec0-2980b694b544`
- Tenant ID: `931e2306-2a26-4cc0-8349-f2d5fa35de74`
- Subscription ID: `49f32f5f-6a02-4fcb-9be8-90d7f9d68233`

Working federated credential:

- Issuer: `https://token.actions.githubusercontent.com`
- Subject: `repo:jdemb/PrototypApka:ref:refs/heads/deploy-2026-05-26`
- Audience: `api://AzureADTokenExchange`

Important fix: the first credential used issuer `https://token.actions.githubusercontent.com/` with a trailing slash. GitHub Actions sends the issuer without the slash, so Azure login failed with `AADSTS700211`. The bad credential was removed; only the no-slash issuer remains.

## GitHub Actions Result

Successful run:

- URL: `https://github.com/jdemb/PrototypApka/actions/runs/26463346629`
- Status: `completed`
- Conclusion: `success`
- Head SHA: `1f52a8c5c71c74585e8351477d3c6138d69e490f`
- Completed/updated: `2026-05-26T17:41:59Z`

The workflow completed:

- Checkout
- Setup .NET
- Restore
- Build
- Publish
- Azure login
- Deploy

## Verification

Local verification:

```powershell
cd apps/api
dotnet restore LiftMate.slnx
dotnet build LiftMate.slnx --no-restore
dotnet test LiftMate.slnx --no-build
```

Observed result:

- Restore: OK
- Build: OK, 0 warnings, 0 errors
- Test: OK, no test projects/output yet

Public smoke checks:

```text
GET https://liftmate-api-dev-jdemb.azurewebsites.net/health -> 200 {"status":"ok"}
GET https://liftmate-api-dev-jdemb.azurewebsites.net/swagger -> 200
GET https://liftmate-api-dev-jdemb.azurewebsites.net/weatherforecast -> 200
```

## Current Deployment Process

For code changes that should deploy to Azure:

1. Switch to `deploy-2026-05-26`.
2. Commit changes that touch `apps/api/**` or `.github/workflows/deploy-api-azure.yml`.
3. Push to `origin/deploy-2026-05-26`.
4. GitHub Actions deploys to `liftmate-api-dev-jdemb`.
5. Verify `/health` and `/swagger`.

Do not deploy from `develop` yet. Do not add Azure SQL or realtime infrastructure until the API contains the first real data model and the trainer/trainee workflow needs persistence.

## Known Caveats

- App Service Free F1 is prototype-only.
- Active region is `westeurope`, not `polandcentral`.
- The current API is still scaffold-level and includes `/weatherforecast`.
- Swagger is public intentionally for this prototype deploy.
- GitHub Actions currently uses branch-specific OIDC credentials for `deploy-2026-05-26`; another branch will need another federated credential or a broader subject pattern.
