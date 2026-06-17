---
project: liftmate-api
researched_at: 2026-05-26
recommended_platform: Azure App Service Free + Azure SQL Database Free
runner_up: Google Cloud Run
context_type: mvp
tech_stack:
  language: C# / .NET
  framework: ASP.NET Core Web API
  runtime: net10.0
cost_priority: free_first
---

## Recommendation

**Deploy the ASP.NET Core API on Azure App Service Free F1 and use Azure SQL Database Free for the MVP data layer.**

This keeps the chosen .NET Web API stack intact and gives the cheapest practical path for a prototype: native ASP.NET Core hosting, managed TLS/routing, Azure-native logs, and a free SQL option. The tradeoff is important: Azure App Service Free/Shared tiers are not production-grade and Free F1 has strict limits, so realtime should start as request/response or light polling. When SignalR/WebSockets become necessary, upgrade App Service and add Azure SignalR Service or run SignalR from the API on a paid plan.

Key sources checked:
- Azure App Service pricing: https://azure.microsoft.com/en-us/pricing/details/app-service/windows/
- Azure App Service limits: https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-app-service-limits
- Azure SQL Database free offer: https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer
- Azure SignalR Service pricing: https://azure.microsoft.com/en-us/pricing/details/signalr-service/
- Google Cloud Run pricing: https://cloud.google.com/run/pricing
- Cloud Run WebSockets: https://cloud.google.com/run/docs/triggering/websockets
- Render free tier: https://render.com/docs/free

## Platform Comparison

| Platform | Runtime fit | Free fit | Realtime fit | CLI-first | Managed ops | Result |
|---|---|---|---|---|---|---|
| Azure App Service Free + Azure SQL Free | Pass | Pass | Partial | Pass | Pass | Recommended |
| Google Cloud Run | Pass | Pass | Partial | Pass | Pass | Runner-up |
| Fly.io | Pass | Partial | Pass | Pass | Partial | Good paid path |
| Railway | Partial | Partial | Pass | Pass | Pass | DX fallback |
| Render Free | Partial | Partial | Partial | Partial | Pass | Not preferred |
| Cloudflare Workers | Fail | Pass | Pass | Pass | Pass | Dropped for .NET |

Cloudflare remains the best free-first option only if the backend changes to Workers-native TypeScript, D1, and Durable Objects. It is not a fit for the current ASP.NET Core `net10.0` runtime. Render Free is not preferred because free web services spin down after idle periods and free Postgres is not a durable MVP database choice. Fly.io remains technically strong for realtime .NET but is no longer the top pick under the free-first constraint.

### Shortlisted Platforms

#### 1. Azure App Service Free + Azure SQL Free (Recommended)

Azure is the most natural free-first path for .NET. App Service Free F1 is enough for early API smoke tests, small private MVP traffic, and mobile integration work. Azure SQL Database Free gives a managed relational database without leaving the Microsoft ecosystem. The limitation is that this is a prototype platform, not the final realtime production setup.

#### 2. Google Cloud Run

Cloud Run is a strong container-based option for ASP.NET Core with a generous free tier and support for WebSockets as long-running HTTP requests. It is less .NET-native than Azure but attractive if the project prefers container portability. The realtime caveat is that open WebSocket connections consume request time and are bounded by request timeout settings.

#### 3. Fly.io

Fly.io is still the best technical match for long-running ASP.NET Core realtime processes, but it is not the best answer when the decision is free-first. Keep it as the upgrade path if Azure's Free F1 limits become painful before the app is ready for paid Azure.

## Anti-Bias Cross-Check: Azure Free-First

### Devil's Advocate - Weaknesses

1. Free F1 has strict resource limits and is explicitly not the right tier for production traffic.
2. Realtime on the free tier is fragile; CPU limits and idle behavior can make WebSocket/SignalR behavior unreliable.
3. Azure can feel heavier than smaller PaaS platforms because resource groups, App Service plans, SQL servers, firewall rules, and connection strings all need configuration.
4. Azure SQL Free is useful, but schema migrations, backups, and data reset behavior still need deliberate handling.
5. The free-first decision may hide the real cost until SignalR, always-on behavior, or higher reliability is required.

### Pre-Mortem - How This Could Fail

Six months after launch, the Azure free-first path could fail if the team treats it like production infrastructure. The API launches on Free F1, the mobile app starts depending on immediate updates during workouts, and polling frequency climbs to compensate for missing realtime. The CPU-minute budget gets consumed by normal testing and trainer demos, so requests become inconsistent right when users are evaluating the app. A later attempt to add SignalR exposes the need for a paid App Service plan or Azure SignalR Service, but that cost was not planned. At the same time, database migrations were run directly against Azure SQL without a rollback habit. The platform choice was reasonable for a prototype, but the failure came from not drawing a hard line between "free MVP validation" and "production-ready realtime service."

### Unknown Unknowns

- Free F1 is a validation tier; it should not be treated as the production target for a public launch.
- Azure SQL Free has monthly free allowances, but database configuration, firewall access, and connection strings still add setup overhead.
- SignalR has a separate Azure service and pricing model; adding it later is not just a code change.
- Mobile clients are harder to roll back than backend services, so API versioning matters once TestFlight/Android builds leave the developer device.
- If polling is used to avoid realtime cost, it can quietly become more expensive or less responsive than a small paid realtime setup.

## Operational Story

- **Preview deploys**: Use a separate Azure Web App or deployment slot once the plan supports it; on Free F1, keep preview simple and deploy only a staging app if needed.
- **Secrets**: Store connection strings and API secrets in App Service configuration. Store deployment credentials in GitHub Secrets once GitHub Actions is added.
- **Rollback**: Use App Service deployment history or redeploy the previous build artifact. Database migrations are not automatically rolled back.
- **Approval**: An agent may run read-only Azure CLI checks and local `dotnet` verification. Production deploys, secret rotation, DB firewall changes, and migrations require human approval.
- **Logs**: Use App Service log streaming for runtime logs and GitHub Actions logs for CI once workflows exist. Locally, keep `dotnet build` and API smoke tests as the first gate.

## Risk Register

| Risk | Source | Likelihood | Impact | Mitigation |
|---|---|---:|---:|---|
| Free F1 limits block demos or early users | Devil's advocate | M | H | Treat Free F1 as prototype-only; define an upgrade trigger before sharing beyond private testers. |
| Realtime does not behave well on the free tier | Devil's advocate | H | M | Start with request/response plus light polling; move to paid App Service or Azure SignalR before promising realtime UX. |
| Azure setup overhead slows after-hours work | Devil's advocate | M | M | Keep the first deploy minimal: one Web App, one SQL database, no advanced networking. |
| Database migration rollback is undefined | Pre-mortem | M | H | Use additive migrations and write a rollback note before any destructive schema change. |
| Polling becomes a hidden cost/performance problem | Unknown unknowns | M | M | Set conservative polling intervals and revisit realtime once the trainer/trainee workflow is implemented. |
| Cloud Run would be simpler if containers become the main path | Research finding | L | M | Re-evaluate before CI/CD if Docker becomes mandatory for local and cloud parity. |

## Getting Started

1. Create an Azure Resource Group for LiftMate MVP infrastructure.
2. Create an App Service plan on Free F1 and an App Service for `apps/api/LiftMate.Api`.
3. Create an Azure SQL Database using the free offer and configure the App Service connection string.
4. Add `appsettings.Production.json` only for non-secret defaults; keep secrets in App Service configuration.
5. Deploy the API with Azure CLI or GitHub Actions after local `dotnet restore LiftMate.slnx` and `dotnet build LiftMate.slnx --no-restore` pass.
6. Keep realtime out of the initial infrastructure contract; add Azure SignalR Service or upgrade App Service when realtime becomes a tested user-facing requirement.

## Out of Scope

The following were not evaluated in this research:
- Docker image implementation details
- GitHub Actions workflow setup
- Production-scale architecture such as multi-region HA, disaster recovery, or formal SLOs
