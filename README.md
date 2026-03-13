# Glaze

Glaze is a tiny macOS menu bar break reminder built to be usable while we develop it.

The first loop is intentionally small:

- a menu bar timer that starts on launch
- a heads-up phase before each break
- a full-screen break overlay on every screen
- one-minute snooze, skip, pause/resume
- simple local settings for work duration, break duration, and heads-up timing

## Why this shape

This repo follows the same spirit as `~/Workspace/Glacier`:

- XcodeGen project
- minimal SwiftUI + AppKit surface
- no third-party dependencies
- product docs kept alongside the code
- usable during development, not just a throwaway prototype

## Run

```bash
xcodegen generate
xcodebuild -project Glaze.xcodeproj -scheme Glaze -configuration Debug build
```

Then launch `Glaze.app` from Xcode or from the built product.

## Current MVP behavior

- The app launches as a menu bar app with no Dock icon.
- A work timer starts immediately.
- When the timer reaches the heads-up threshold, the app switches to a warning state.
- When the timer expires, a break overlay covers each display.
- When the break ends, the next work cycle starts automatically.

## Not in MVP yet

- auto-pause for meetings, media, or idle
- floating countdown near the cursor
- posture/blink reminders
- Apple Shortcuts / AppleScript hooks
- local notification permissions flow
- onboarding and polished settings window

More detail lives in [docs/mvp-scope.ko.md](/Users/fran/Workspace/Glaze/docs/mvp-scope.ko.md).
