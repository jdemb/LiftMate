# Refine Trainer Trainee Detail

## Scope

Remove the entire `Dane relacji` section from the trainer's trainee-detail screen. This includes the section heading, the trainee e-mail row, the active relationship status row, and spacing owned by that section.

Replace the static `Połączona` text under the trainee name with a grammatical relationship status and connection month, for example `Połączona od marca 2026`, `Połączony od marca 2026`, or the neutral fallback `Połączono od marca 2026`.

Do not change other trainer screens, trainee-facing screens, or HTML design files.

## Implementation

Delete the relationship-data widgets directly from `TrainerTraineeDetailScreen`. The screen is trainer-specific, so no additional role flag or conditional rendering is needed.

Add a nullable relationship timestamp to the trainee user record. Set it when a trainee registers with a trainer and whenever a trainee claims a trainer invite code. Expose the resolved connection timestamp in the trainer relationship response.

For an existing linked trainee without the new timestamp, use the creation time of their oldest refresh token as the registration-date fallback. If no refresh token exists, return no timestamp and render only the grammatical status without `od <miesiąc> <rok>`.

Determine the status from the first name using a dedicated mobile formatter with Polish rules and explicit exceptions. Return `Połączona` for confidently feminine names, `Połączony` for confidently masculine names, and `Połączono` when the name is empty, foreign, or ambiguous. Format Polish month names in the genitive case and lowercase.

Keep the weekly streak, guidance, assigned workout sets, history, and trainer navigation unchanged apart from the already requested navigation edits in the working tree.

## Verification

Add API tests for storing a new connection timestamp and resolving the oldest-refresh-token fallback. Add model and formatter tests for the timestamp contract, feminine, masculine, and neutral statuses, all Polish month forms, and a missing timestamp. Add widget regression assertions proving that the new status is shown and `Dane relacji`, `E-mail`, and `Aktywna relacja` are absent while adjacent trainee-detail content remains visible.

Run targeted API and Flutter tests, the complete API and Flutter test suites, `dotnet build`, and `flutter analyze`.
