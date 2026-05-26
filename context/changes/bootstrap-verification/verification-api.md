---
bootstrapped_at: 2026-05-26T15:46:33.1607835+02:00
starter_id: dotnet
starter_name: ".NET (ASP.NET Core webapi)"
project_name: liftmate-api
language_family: dotnet
package_manager: dotnet
cwd_strategy: native-cwd
bootstrapper_confidence: verified
phase_3_status: ok
audit_command: "dotnet list package --vulnerable"
---

## Hand-off

```yaml
starter_id: dotnet
package_manager: dotnet
project_name: liftmate-api
hints:
  language_family: dotnet
  team_size: solo
  deployment_target: self-host
  ci_provider: github-actions
  ci_default_flow: auto-deploy-on-merge
  bootstrapper_confidence: verified
  path_taken: standard
  quality_override: false
  self_check_answers: null
  has_auth: true
  has_payments: false
  has_realtime: true
  has_ai: false
  has_background_jobs: false
```

.NET Web API is the backend starter for LiftMate because the Flutter app needs a trusted server boundary for auth, trainer-trainee permissions, training data, and realtime synchronization. The repository already uses `apps/mobile` for Flutter, so the API is scaffolded separately under `apps/api` while preserving the monorepo root for shared docs and context. The hand-off keeps auth and realtime as product needs; the initial scaffold is the official ASP.NET Core Web API template, with concrete auth, database, and realtime choices left for implementation planning.

## Pre-scaffold verification

| Signal      | Value   | Severity | Notes |
| ----------- | ------- | -------- | ----- |
| npm package | not run | n/a      | not applicable for .NET starter |
| GitHub repo | not run | n/a      | registry docs_url is Microsoft Learn, not a GitHub repository URL |

## Scaffold log

**Resolved invocation**: `dotnet new sln -n LiftMate`; `dotnet new webapi -n LiftMate.Api --no-restore`; `dotnet sln LiftMate.slnx add LiftMate.Api\LiftMate.Api.csproj`
**Strategy**: native-cwd in `apps/api`
**Exit code**: 0
**Files written by CLI**: solution plus ASP.NET Core Web API project files
**Pre-existing files preserved**: none; `apps/api` was empty before scaffold

Note: .NET 10 generated `LiftMate.slnx` rather than a classic `.sln` file.

## Post-scaffold audit

**Tool**: `dotnet list LiftMate.slnx package --vulnerable --include-transitive`
**Summary**: 0 CRITICAL, 0 HIGH, 0 MODERATE, 0 LOW
**Direct vs transitive**: no vulnerable packages reported by NuGet for `LiftMate.Api`.

Additional verification run after scaffold:
- `dotnet restore LiftMate.slnx` exited 0.
- `dotnet build LiftMate.slnx --no-restore` exited 0 with 0 warnings and 0 errors.
- Generated `bin/` and `obj/` directories were removed after adding .NET ignore rules.

## Hints recorded but not acted on

| Hint                    | Value |
| ----------------------- | ----- |
| bootstrapper_confidence | verified |
| quality_override        | false |
| path_taken              | standard |
| self_check_answers      | null |
| team_size               | solo |
| deployment_target       | self-host |
| ci_provider             | github-actions |
| ci_default_flow         | auto-deploy-on-merge |
| has_auth                | true |
| has_payments            | false |
| has_realtime            | true |
| has_ai                  | false |
| has_background_jobs     | false |

## Next steps

Next: design the backend slices before implementation: auth, trainer-trainee relationship, workout template ownership, training progress persistence, and realtime update strategy.

Useful manual steps in the meantime:
- Run `dotnet build apps/api/LiftMate.slnx` after pulling or changing backend code.
- Decide whether realtime will use SignalR, polling, or a hosted realtime service.
- Decide persistence/auth strategy before adding domain endpoints.
