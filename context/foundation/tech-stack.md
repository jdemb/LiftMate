---
starter_id: flutter
package_manager: pub
project_name: liftmate
hints:
  language_family: dart
  team_size: solo
  deployment_target: playstore
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

Flutter is the recommended Dart starter for a mobile-only MVP and fits LiftMate's two-week after-hours timeline because it gives one typed, convention-based codebase for Android and iOS. You have prior Flutter experience, and the starter has verified bootstrapper support, so scaffolding risk is low. The hand-off records auth and realtime as product needs; Flutter covers the mobile app surface, while backend, data access, and realtime synchronization remain implementation decisions for the next step. The primary deployment target is Android distribution, with iOS TestFlight builds noted as part of the intended release workflow.
