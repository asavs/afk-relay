# Exp IRL

Exp IRL is a native iOS survival game where real-world walking becomes tactical
movement. Every eligible HealthKit step mints one movement token. In the arena,
the player has no attack: survival depends on positioning enemies so their
telegraphed attacks hit one another.

> **Status:** Initial application scaffold. The shell, arena placeholder,
> lifecycle state machine, and test targets exist; the HealthKit economy and
> playable combat loop have not been implemented yet.

## MVP

- Native iOS app built with SwiftUI, SpriteKit, GameplayKit, and HealthKit.
- One credited real-world step creates exactly one movement token.
- Player-commanded movement is the only use of movement tokens.
- The player has no attack, building action, spell, or defense.
- Enemy attacks use friendly fire and never damage their source.
- State remains on device; the MVP has no account or custom backend.
- Primitive sci-fi geometry is intentional.

## Current scaffold

- `AppShellView` embeds the SpriteKit arena in SwiftUI.
- `ArenaScene` renders a primitive arena and centered player placeholder.
- `ArenaLifecycleMachine` uses `GKStateMachine` for ready, running, and paused
  transitions.
- Swift Testing covers deterministic lifecycle behavior.
- XCTest provides the UI-test target.

## Requirements

- macOS with Xcode 26.6 or a compatible newer release.
- An iOS simulator for scaffold development.
- A signed physical iPhone and Apple Developer configuration for HealthKit
  integration and device acceptance checks.

The scaffold currently uses an iOS 26.5 deployment target as a provisional
project setting. The supported OS, device, and orientation matrix remains an
explicit product decision.

## Open and run

1. Open `ExpIRL.xcodeproj` in Xcode.
2. Select the `ExpIRL` scheme.
3. Choose an iPhone simulator.
4. Run with **Product → Run** (`⌘R`).

Run the test suite with **Product → Test** (`⌘U`). A command-line scaffold build
can also be started from this repository root:

```sh
xcodebuild \
  -project ExpIRL.xcodeproj \
  -scheme ExpIRL \
  -destination 'generic/platform=iOS Simulator' \
  build
```

HealthKit behavior must ultimately be verified on signed physical hardware; the
domain economy will use a fake health provider in deterministic tests.

## Repository layout

```text
ExpIRL/
  App/                 SwiftUI entry point and application shell
  Game/                SpriteKit and GameplayKit integration
  Assets.xcassets/     App icons, colors, and visual assets
ExpIRLTests/           Swift Testing unit and integration tests
ExpIRLUITests/         XCTest UI tests
ExpIRL.xcodeproj/      Xcode project
```

## Documentation

The canonical product and engineering specification lives in the companion
GitHub Wiki. In the paired local checkout, that repository is located at
`../wiki/`.

Coding agents must follow [AGENTS.md](AGENTS.md) before changing implementation
code. Proposals in the wiki describe possible future work and are not approved
MVP scope.

## Privacy

The MVP reads step count only. HealthKit framework values stop at the health
adapter boundary, health-derived measurements are not used for advertising or
marketing, and the game does not require a custom network service.

## License

Copyright is reserved. No permission to reuse, modify, or distribute this
software is granted without prior written authorization. See [LICENSE](LICENSE).
