---
bootstrapped_at: 2026-05-23T17:59:27.8011634+02:00
starter_id: flutter
starter_name: Flutter
project_name: liftmate
language_family: dart
package_manager: pub
cwd_strategy: subdir-then-move
bootstrapper_confidence: verified
phase_3_status: failed
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

**Resolved invocation**: `flutter create -e .bootstrap-scaffold --org com.example --platforms android,ios,web`
**Strategy**: subdir-then-move
**Exit code**: 1

**Stderr (last 20 lines)**:

```text
flutter : The term 'flutter' is not recognized as the name of a cmdlet, function, script file, or operable program.
Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
At line:2 char:1
+ flutter create -e .bootstrap-scaffold --org com.example --platforms a ...
+ ~~~~~~~
    + CategoryInfo          : ObjectNotFound: (flutter:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CommandNotFoundException
```

**.bootstrap-scaffold left in place at**: not created.

## Post-scaffold audit

**Audit not run**: scaffold halted during the scaffold command; no project to audit.

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

Install Flutter SDK and make sure `flutter` is available on PATH, then re-run `/10x-bootstrapper`.

Useful manual checks before retry:
- `flutter --version`
- `flutter doctor`
- Confirm Android tooling is installed if Android builds are required.
- Confirm Xcode/macOS availability separately for iOS/TestFlight builds; iOS builds cannot be produced directly on Windows.
