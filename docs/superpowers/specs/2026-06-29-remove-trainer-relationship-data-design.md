# Remove Trainer Relationship Data

## Scope

Remove the entire `Dane relacji` section from the trainer's trainee-detail screen. This includes the section heading, the trainee e-mail row, the active relationship status row, and spacing owned by that section.

Do not change relationship data models, API responses, other trainer screens, trainee-facing screens, or HTML design files.

## Implementation

Delete the relationship-data widgets directly from `TrainerTraineeDetailScreen`. The screen is trainer-specific, so no additional role flag or conditional rendering is needed.

Keep the weekly streak, guidance, assigned workout sets, history, and trainer navigation unchanged apart from the already requested navigation edits in the working tree.

## Verification

Add a widget regression assertion proving that `Dane relacji`, `E-mail`, and `Aktywna relacja` are absent while adjacent trainee-detail content remains visible. Run the targeted trainee-detail tests, the full Flutter test suite, and `flutter analyze`.
