---
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
---

## Why this stack

.NET Web API is the backend starter for LiftMate because the Flutter app needs a trusted server boundary for auth, trainer-trainee permissions, training data, and realtime synchronization. The repository already uses `apps/mobile` for Flutter, so the API is scaffolded separately under `apps/api` while preserving the monorepo root for shared docs and context. The hand-off keeps auth and realtime as product needs; the initial scaffold is the official ASP.NET Core Web API template, with concrete auth, database, and realtime choices left for implementation planning.
