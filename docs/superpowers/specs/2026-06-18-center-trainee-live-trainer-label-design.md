# Center Trainee Live Trainer Label

## Scope

Adjust only the trainer-led, read-only trainee live-session header.

## Design

- Keep the back button aligned to the left and preserve its current callback.
- Center the status group consisting of the red live dot and `Prowadzi trener <name>` relative to the full screen width.
- Use a layered header layout so the centered group is independent of the back button width.
- Preserve the existing trainer first-name and email-fallback logic.
- Do not change editable live-session headers or session behavior.

## Verification

- Add a widget assertion proving the status group's horizontal center matches the screen center.
- Keep the existing assertion that the back button returns to the trainee home screen without completing or cancelling the session.
- Run the focused widget test, the full Flutter test suite, and `flutter analyze`.
