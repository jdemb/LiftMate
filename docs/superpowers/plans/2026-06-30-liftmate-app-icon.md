# LiftMate App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every default Flutter launcher icon with the approved dynamic dumbbell icon on Android, iOS, and web.

**Architecture:** Keep two checked-in 1024×1024 source PNGs under `apps/mobile/assets/icon`: a complete opaque icon for iOS, legacy Android, and web, plus a transparent dumbbell foreground for Android adaptive masks. Configure `flutter_launcher_icons` once in `pubspec.yaml` and commit its generated platform resources so builds do not depend on generation at release time.

**Tech Stack:** Flutter, Dart, `flutter_launcher_icons` 0.14.4, Android adaptive icons, iOS asset catalogs, web manifest icons

---

## File map

- Create `apps/mobile/assets/icon/app_icon.png`: opaque 1024×1024 master icon with blue gradient and white angled dumbbell.
- Create `apps/mobile/assets/icon/app_icon_foreground.png`: transparent 1024×1024 Android adaptive foreground containing only the white angled dumbbell with safe padding.
- Modify `apps/mobile/pubspec.yaml`: add the icon generator and cross-platform configuration.
- Modify `apps/mobile/pubspec.lock`: lock the added development dependency.
- Regenerate `apps/mobile/android/app/src/main/res/mipmap-*`, adaptive-icon XML and supporting Android resources.
- Regenerate `apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/*` and its `Contents.json` if the generator updates it.
- Regenerate `apps/mobile/web/favicon.png`, `apps/mobile/web/icons/*`, and update `apps/mobile/web/manifest.json` theme/background colors.

### Task 1: Add approved source artwork

**Files:**
- Create: `apps/mobile/assets/icon/app_icon.png`
- Create: `apps/mobile/assets/icon/app_icon_foreground.png`

- [ ] **Step 1: Generate the opaque master icon**

Create a 1024×1024 PNG matching the approved design: rounded-square blue gradient from `#4F7CFF` at top-left to `#2457D6` at bottom-right, centered white symmetric dumbbell rotated 28 degrees counter-clockwise, no text, no shadow outside the square, and no alpha channel. Keep the dumbbell inside the central 66% of the canvas so it remains legible at favicon size.

- [ ] **Step 2: Generate the adaptive foreground**

Create a transparent 1024×1024 PNG containing the same white dumbbell at the same angle. Keep all visible pixels inside the central 58% of the canvas; Android will supply the blue background and apply the final launcher mask.

- [ ] **Step 3: Verify dimensions and transparency**

Run from `apps/mobile`:

```powershell
Add-Type -AssemblyName System.Drawing
$full = [System.Drawing.Bitmap]::FromFile((Resolve-Path 'assets/icon/app_icon.png'))
$foreground = [System.Drawing.Bitmap]::FromFile((Resolve-Path 'assets/icon/app_icon_foreground.png'))
"full=$($full.Width)x$($full.Height) alpha=$([System.Drawing.Image]::IsAlphaPixelFormat($full.PixelFormat))"
"foreground=$($foreground.Width)x$($foreground.Height) alpha=$([System.Drawing.Image]::IsAlphaPixelFormat($foreground.PixelFormat))"
$full.Dispose(); $foreground.Dispose()
```

Expected:

```text
full=1024x1024 alpha=False
foreground=1024x1024 alpha=True
```

- [ ] **Step 4: Commit source artwork**

```powershell
git add apps/mobile/assets/icon/app_icon.png apps/mobile/assets/icon/app_icon_foreground.png
git commit -m "mobile: dodaj źródła ikony LiftMate"
```

### Task 2: Configure and generate launcher icons

**Files:**
- Modify: `apps/mobile/pubspec.yaml`
- Modify: `apps/mobile/pubspec.lock`
- Modify: generated Android, iOS, and web icon resources listed in the file map

- [ ] **Step 1: Add the generator dependency and configuration**

In `apps/mobile/pubspec.yaml`, add this development dependency:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.14.4
```

Add this top-level block after the dependency sections:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: assets/icon/app_icon.png
  adaptive_icon_background: "#2457D6"
  adaptive_icon_foreground: assets/icon/app_icon_foreground.png
  adaptive_icon_foreground_inset: 16
  remove_alpha_ios: true
  background_color_ios: "#2457D6"
  web:
    generate: true
    image_path: assets/icon/app_icon.png
    background_color: "#2457D6"
    theme_color: "#2457D6"
```

- [ ] **Step 2: Resolve dependencies**

Run from `apps/mobile`:

```powershell
flutter pub get
```

Expected: exit code 0 and `flutter_launcher_icons` recorded in `pubspec.lock`.

- [ ] **Step 3: Generate platform resources**

Run from `apps/mobile`:

```powershell
dart run flutter_launcher_icons
```

Expected: exit code 0 with successful Android, iOS, and web generation messages.

- [ ] **Step 4: Prove default Flutter artwork is replaced**

Run from the repository root:

```powershell
git status --short apps/mobile/android/app/src/main/res apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset apps/mobile/web apps/mobile/pubspec.yaml apps/mobile/pubspec.lock
```

Expected: modified/generated icon files for Android, iOS, and web, plus `pubspec.yaml` and `pubspec.lock`.

- [ ] **Step 5: Commit generated configuration and resources**

```powershell
git add apps/mobile/pubspec.yaml apps/mobile/pubspec.lock apps/mobile/android/app/src/main/res apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset apps/mobile/web/favicon.png apps/mobile/web/icons apps/mobile/web/manifest.json
git commit -m "mobile: ustaw ikonę aplikacji LiftMate"
```

### Task 3: Verify generated icons and Flutter project

**Files:**
- Inspect: generated platform icon resources

- [ ] **Step 1: Verify key output files exist and are non-empty**

Run from the repository root:

```powershell
$paths = @(
  'apps/mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
  'apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
  'apps/mobile/web/favicon.png',
  'apps/mobile/web/icons/Icon-512.png',
  'apps/mobile/web/icons/Icon-maskable-512.png'
)
$paths | ForEach-Object { $item = Get-Item $_; "{0} {1}" -f $item.FullName, $item.Length }
```

Expected: all five paths resolve and every reported size is greater than zero.

- [ ] **Step 2: Run the mobile static analysis gate**

Run from `apps/mobile`:

```powershell
flutter analyze
```

Expected: `No issues found!` and exit code 0.

- [ ] **Step 3: Run the mobile test suite**

Run from `apps/mobile`:

```powershell
flutter test
```

Expected: all tests pass and exit code 0.

- [ ] **Step 4: Build Android resources**

Run from `apps/mobile`:

```powershell
flutter build apk --debug
```

Expected: exit code 0 and a debug APK under `build/app/outputs/flutter-apk/`.

- [ ] **Step 5: Inspect the final icon visually**

Open the 1024px iOS icon and the 512px maskable web icon. Confirm the dumbbell is white, angled counter-clockwise, centered, not clipped, and clearly visible at small scale. On an Android emulator/device, install the debug APK and confirm at least one circular or squircle launcher mask does not crop the dumbbell.

- [ ] **Step 6: Commit any verification-driven corrections**

If verification required artwork or inset corrections, regenerate all platform resources and commit only those corrections:

```powershell
git add apps/mobile/assets/icon apps/mobile/android/app/src/main/res apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset apps/mobile/web
git commit -m "mobile: popraw marginesy ikony LiftMate"
```
