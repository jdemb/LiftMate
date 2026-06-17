---
bootstrapped_at: 2026-05-23T19:13:18.6890015+02:00
starter_id: flutter
starter_name: Flutter
project_name: liftmate
language_family: dart
package_manager: pub
cwd_strategy: subdir-then-move
bootstrapper_confidence: verified
phase_3_status: ok
audit_command: "null"
---

## Hand-off

```yaml
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
```

Flutter is the recommended Dart starter for a mobile-only MVP and fits LiftMate's two-week after-hours timeline because it gives one typed, convention-based codebase for Android and iOS. You have prior Flutter experience, and the starter has verified bootstrapper support, so scaffolding risk is low. The hand-off records auth and realtime as product needs; Flutter covers the mobile app surface, while backend, data access, and realtime synchronization remain implementation decisions for the next step. The primary deployment target is Android distribution, with iOS TestFlight builds noted as part of the intended release workflow.

## Pre-scaffold verification

| Signal      | Value   | Severity | Notes |
| ----------- | ------- | -------- | ----- |
| npm package | not run | n/a      | not applicable for Dart/Flutter starter |
| GitHub repo | not run | n/a      | registry docs_url is not a GitHub repository URL |

## Scaffold log

**Resolved invocation**: `flutter create -e --project-name liftmate --org com.example --platforms android,ios,web bootstrap_scaffold`
**Strategy**: subdir-then-move, with Flutter-compatible temp directory name `bootstrap_scaffold`
**Exit code**: 0
**Files moved**: 97
**Conflicts (.scaffold siblings)**: README.md
**.gitignore handling**: moved silently
**bootstrap_scaffold cleanup**: deleted

Note: the registry template form `flutter create -e .bootstrap-scaffold --org com.example --platforms android,ios,web` failed before scaffolding because `.bootstrap-scaffold` is not a valid Dart package name. The successful invocation used `bootstrap_scaffold` as a temporary directory and `--project-name liftmate` to preserve the intended package name.

## Post-scaffold audit

**Tool**: skipped - no built-in audit tool for dart
**Recommended external tool**: `dart pub outdated --mode=null-safety` is the closest built-in dependency freshness check.

Additional verification run after scaffold:
- `flutter pub get` exited 0 and refreshed dependencies.
- `flutter analyze` exited 0 with `No issues found`.

## Hints recorded but not acted on

| Hint                    | Value |
| ----------------------- | ----- |
| bootstrapper_confidence | verified |
| quality_override        | false |
| path_taken              | standard |
| self_check_answers      | null |
| team_size               | solo |
| deployment_target       | playstore |
| ci_provider             | github-actions |
| ci_default_flow         | auto-deploy-on-merge |
| has_auth                | true |
| has_payments            | false |
| has_realtime            | true |
| has_ai                  | false |
| has_background_jobs     | false |

## Next steps

Next: a future skill will set up agent context (CLAUDE.md, AGENTS.md). For now, the project is scaffolded and verified.

Useful manual steps in the meantime:
- Review `README.md.scaffold` and decide whether to merge any starter README content into `README.md`.
- Address dependency freshness when appropriate; `flutter pub get` reported four packages with newer versions incompatible with current constraints.
- Plan backend, auth, and realtime synchronization separately; Flutter covers the mobile app surface, not trusted database access.
