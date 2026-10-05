# Repository Guidelines

## Project Structure & Module Organization

**Jumpo** (Jump in the specifications) is a native macOS app/window switcher. The Swift package implements a prototype, not full V1.0.

- `Sources/JumpoCore/`: configuration, persistence, shortcut transactions, and asynchronous activation coordination.
- `Sources/Jumpo/`: SwiftUI views, AppKit lifecycle/menu bar, and platform services.
- `Tests/JumpoCoreTests/`: Swift Testing behavioral tests.
- `Resources/Info.plist` and `scripts/`: bundle metadata and build tools.
- `Tools/WindowFixture.swift`: disposable windows for native integration checks.
- `docs/product/`: current product requirements and UI/interaction specifications.
- `docs/technical/`: technical feasibility analysis and pre-development review decisions.
- `docs/validation/Prototype_Validation.md`: observed verification and remaining checks.
- `docs/archive/2026-09-30_before_review/`: original specifications; preserve these snapshots. `docs/product/` and `docs/technical/` contain the current revisions.
- `docs/README.md`: documentation index, naming rules, and maintenance conventions.

## Build, Test, and Development Commands

Use macOS, Apple Swift 6, and a macOS SDK. No third-party dependencies. Run from the repository root:

```sh
bash scripts/swift.sh build                 # Compile
bash scripts/swift.sh test --disable-xctest  # Run Swift Testing
bash scripts/build.sh                       # Package and ad hoc sign
open dist/Jumpo.app                         # Run the application
```

Keep `.build/` and `dist/` untracked. macOS 14 support is provisional; record tested environments.

## Coding Style & Naming Conventions

Use four-space Swift indentation, `UpperCamelCase` types, and `lowerCamelCase` members. Keep UI and application coordination on `@MainActor`; isolate filesystem configuration and pure state logic in JumpoCore. Prefer injected protocols for OS interactions.

Preserve Chinese UI/document prose and established API names. Follow `Jump_<Topic>_V<major>.<minor>.md` for specifications. Keep cross-document references aligned. No formatter or linter is configured.

## Validation & Testing Guidelines

Use descriptive behavioral `@Test` names in `*Tests.swift`. Test persistence failures, rollback, duplicate binding, and stale asynchronous callbacks. No coverage percentage is enforced. Changes to OS integration also need real app checks; passing mocks does not prove focus, permissions, Spaces, or window behavior.

Follow PRD section 26 and technical sections 33–34 for broader acceptance. Preserve Window Picker as V1.1/P1. Distinguish automated tests, native UI inspection, and untested release requirements.

## Commit & Pull Request Guidelines

Use imperative commit subjects, for example `docs: clarify HUD dismissal behavior`. Prefix with the affected area (`feat`, `fix`, `docs`, `build`, `test`) when it helps scanning. Keep `.build/` and `dist/` out of commits.

Pull requests should describe the change, reference affected specification sections and relevant issues, list validation performed, and include screenshots for UI changes.

## Product & Privacy Constraints

Register only enabled, bound slots. Publish configuration after successful persistence; restore registration on failure. Verify actual app/window focus before reporting success. Preserve application fallback without Accessibility. Keep AX references in memory, off MainActor, with bounded calls and cancellation checks. Ad hoc builds are not notarized releases.
