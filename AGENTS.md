# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Verify UI in the Simulator

When implementing designs or features, use the **/serve-sim** skill to run the app in an iOS Simulator and check the UI and functionality yourself (screenshots, taps, gestures, rotation). Do not consider UI work done on a successful build alone — look at the rendered result in both scenes (see Design below).

## Commands

Paths and target names contain spaces — always quote them.

```sh
# Build
xcodebuild build -project "Dear Diary.xcodeproj" -scheme "Dear Diary" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run all tests
xcodebuild test -project "Dear Diary.xcodeproj" -scheme "Dear Diary" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run a single test class (or append /testMethod)
xcodebuild test -project "Dear Diary.xcodeproj" -scheme "Dear Diary" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:"Dear DiaryTests/DiaryStoreTests"

# Format (config in .swiftformat: 2-space indent)
swiftformat .
```

The project uses the Inject package for hot reload during development.

## Architecture

SwiftUI iOS app for two people (a couple) sharing one diary. No custom backend — sync is iCloud CloudKit Sharing. `ARCHITECTURE.md` is the authoritative sync design doc; read it before touching anything in `Dear Diary/Store/`.

- **Local-first stores** (`Dear Diary/Store/`): plain JSON files, one store per domain (`DiaryStore`, `ToDoStore`, `CoupleSpaceStore`, ...). UI renders from local stores; user actions write locally first, sync catches up in the background.
- **Shared data root**: all synced records belong to one `CoupleSpace` record; a `CKShare` on it gives the partner access.
- **Sync engine** (`Store/Sync/`): `CloudKitSyncCoordinator` owns sync. It runs two `CKSyncEngine` instances — the owner syncs through the private database, the participant through the shared database — and every send/fetch branches on role. `CloudKitSyncService` is deprecated scaffolding; only its `containerIdentifier` constant is still referenced.
- **Change-tag persistence gotcha**: because local stores are JSON (not a CKRecord mirror), each record's CKRecord system fields must be persisted (`encodeSystemFields`) across launches and restored before saving. Without the saved change tag, edits are rejected as `serverRecordChanged` and silently dropped after relaunch.
- **Conflicts**: latest-wins on fetch (compare `updatedAt`, tie-break by `modifiedByDeviceID`); on push rejection the local values win. Deletes are soft (`deletedAt` tombstones).
- **Share acceptance**: `CKSharingSupported` must stay in Info.plist, and shares are accepted in `UIWindowSceneDelegate.userDidAcceptCloudKitShareWith` (the `UIApplicationDelegate` variant is never called); metadata arriving before the handler is wired gets buffered.

Feature folders (`Home/`, `Diary/`, `To Do/`, `Settings/`) hold views; shared visual pieces live in `UI Components/`.

## Design

`DESIGN.md` (visual direction) and `CONTEXT.md` (vocabulary) govern all UI work. The essentials:

- The app has two **scenes**, not light/dark modes: **Morning** (warm cream/blush/rose) and **Candlelight** (genuinely dark, warm-lit, ember accent). Never treat Candlelight as Morning dimmed. Verify UI changes in both.
- Colors are **semantic roles** (Backdrop, Surface, Surface Muted, Ink, Ink Muted, Romance Accent, Heart Rose, Sage, Plum) defined in the asset catalog. Never add one-off colors — extend the roles.
- **Warmth bridge**: no neutral gray, no pure black, no cool tint anywhere, in either scene. Ember is night-only; Heart Rose applies to heart glyphs only.
- **4pt grid**: spacing, sizing, corner radius, and touch-target values are multiples of 4. Exception: true 1px hairlines (borders, dividers).
- Use the exact vocabulary from `CONTEXT.md` (scene, not theme; Romance Accent, not primary color).
