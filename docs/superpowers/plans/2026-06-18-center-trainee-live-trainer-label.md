# Center Trainee Live Trainer Label Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Center the trainer status group in the trainer-led, read-only trainee live-session header while preserving left-aligned back navigation.

**Architecture:** Replace the header's sequential `Row` with a full-width `Stack`. Keep the back button positioned on the left and place the live-dot-and-label group at `Alignment.center`, making its position independent of the navigation control.

**Tech Stack:** Flutter, Dart, `flutter_test`

---

### Task 1: Add the layout regression test

**Files:**
- Modify: `apps/mobile/test/post_auth_relationship_screen_test.dart`

- [ ] **Step 1: Extend the existing trainer-led read-only widget test**

After locating `Prowadzi trener Test`, calculate the screen center and the horizontal center of the status group. Identify the group bounds using keys added by the implementation:

```dart
final header = tester.getRect(
  find.byKey(const ValueKey('read-only-live-header')),
);
final trainerStatus = tester.getRect(
  find.byKey(const ValueKey('read-only-live-trainer-status')),
);

expect(trainerStatus.center.dx, closeTo(header.center.dx, 0.5));
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
flutter test test/post_auth_relationship_screen_test.dart --plain-name "trainee trainer-led read-only live has back action and trainer first name"
```

Expected: FAIL because the keyed centered header/status widgets do not exist yet.

### Task 2: Center the status group

**Files:**
- Modify: `apps/mobile/lib/shared_sessions/live_session_screen.dart`

- [ ] **Step 1: Replace the read-only header row with a stack**

Use a full-width keyed `Stack`, keep the back action left-aligned, and center a keyed row containing the existing red dot and trainer label:

```dart
SizedBox(
  key: const ValueKey('read-only-live-header'),
  width: double.infinity,
  child: Stack(
    alignment: Alignment.center,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: 'Wróć',
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded, size: 30),
        ),
      ),
      Row(
        key: const ValueKey('read-only-live-trainer-status'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4D4D),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            _readOnlySessionLabel(session, trainerDisplayName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFF8D8D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ],
  ),
)
```

Keep `_readOnlySessionLabel(session, trainerDisplayName)` unchanged.

- [ ] **Step 2: Run the focused test and verify it passes**

Run:

```powershell
flutter test test/post_auth_relationship_screen_test.dart --plain-name "trainee trainer-led read-only live has back action and trainer first name"
```

Expected: PASS.

### Task 3: Verify the mobile project

**Files:**
- No additional files.

- [ ] **Step 1: Run the full Flutter test suite**

Run from `apps/mobile`:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 2: Run static analysis**

Run from `apps/mobile`:

```powershell
flutter analyze
```

Expected: no issues found.

- [ ] **Step 3: Commit the implementation**

```powershell
git add apps/mobile/lib/shared_sessions/live_session_screen.dart apps/mobile/test/post_auth_relationship_screen_test.dart
git commit -m "mobile: center trainee live trainer label"
```
