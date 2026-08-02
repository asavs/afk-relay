# Agent operating contract

This application repository uses the companion Markdown wiki at `../wiki/` as
its product and engineering source of truth. The wiki is a separate Git
repository.

## Before changing code

1. Read [`../wiki/Home.md`](../wiki/Home.md).
2. Read the relevant pages under `../wiki/canonical/`, starting with the
   [product charter](../wiki/canonical/product-charter.md).
3. Read all accepted decision records under `../wiki/decisions/` that those
   pages link.
4. Check [open questions](../wiki/open-questions.md) for affected
   uncertainties.
5. Treat files under [`../wiki/proposals/`](../wiki/proposals/) as
   unauthorized future work unless the current user request explicitly
   promotes or asks for that scope.

If the companion wiki checkout is unavailable, retrieve the main repository's
GitHub Wiki before making behavior or architecture changes.

## Non-negotiable MVP constraints

- Preserve the sacred economy: one credited real-world step mints exactly one
  movement token.
- Never sell, boost, trade, or otherwise monetize movement tokens.
- The player has no attack, building, or defensive ability in the MVP.
- Enemy attacks use friendly fire and never damage their source.
- Do not import `HealthKit` in an `SKScene` or any SpriteKit gameplay target.
- Do not pass HealthKit framework types across the health adapter boundary.
- Do not add a custom backend, accounts, cloud saves, analytics, or spoof
  detection without a new explicit decision.
- Keep combat mechanics independent of theme and art. Gameplay definitions use
  semantic presentation roles; framework rendering resolves concrete resources
  through a replaceable catalog.
- Use primitive sci-fi shapes for the MVP arena's placeholder presentation.
  Do not treat that temporary gameplay skin as the permanent product identity
  or as a restriction on future player-selectable themes.

## Change discipline

- Do not silently choose a high-impact open question. Use a documented
  provisional default only for a reversible spike, or ask for a decision.
- A behavior change must update its canonical requirement and acceptance
  criteria in the same change.
- A new product or architecture decision must be recorded as an ADR under
  `../wiki/decisions/`.
- Keep requirement IDs (`REQ-*`), question IDs (`Q-*`), decision IDs
  (`ADR-*`), and acceptance IDs (`AC-*`) stable. Do not reuse retired IDs.
- Add deterministic tests for domain rules. HealthKit access itself is covered
  by adapter integration and real-device checks; unit tests use a fake health
  provider.
- Persist the step credit and its synchronization checkpoint atomically so a
  crash cannot credit the same HealthKit data twice.
- Update
  [`../wiki/implementation-status.md`](../wiki/implementation-status.md) only
  after linked code and verification evidence exist.

## Verification

- Run `xcodebuild -testPlan AFKRelay-Full` on a simulator before committing.
  Architecture tests only run where the build host's source tree is reachable.
- Run `xcodebuild -testPlan AFKRelay-Device` on the physical device before
  calling a change verified. The device must be unlocked, and its developer
  certificate occasionally needs re-trusting after a re-sign.
- A green simulator run is not device evidence, and neither is evidence of a
  visual change. Changes to appearance need screenshots and the owner's
  approval before they are committed.
- Run the device plan with `./scripts/device-test.sh`. It unlocks the signing
  keychain and passes the App Store Connect key so provisioning updates
  headlessly. Signing over SSH cannot use the login keychain: keychain unlock
  does not cross macOS security sessions, and macOS will not export an
  identity to a non-GUI session either, so signing lives in a dedicated
  keychain created once by `./scripts/setup-signing-keychain.py`.

## Shipping

- Releases are tagged as bare version numbers — `0.1.0`, never `v0.1.0`.
- Cut a release at a boundary the history already has. Fixes accumulate into a
  patch release; the first `feat:` after the previous tag begins the next minor
  release. Do not invent a boundary mid-era.
- A release exists in four places, and all four must agree: the annotated tag,
  the GitHub release, a row in the wiki's release ledger, and
  `MARKETING_VERSION` in the Xcode project.
- Run `./scripts/check-release-sync.sh` before and after cutting a release. It
  reports drift across all four and exits non-zero on any.
- Build and upload with `./scripts/release.sh <tag> <build-number>`. It builds
  the tag from a scratch worktree, so the archive matches the tag rather than
  the working tree.
- Put a build in front of external testers with
  `./scripts/submit-beta.py <tag> <what-to-test-file>`. Uploading alone queues
  nothing: external testing needs the build attached to an external group and
  submitted for review. The script is safe to re-run, so tester notes can be
  corrected after submitting.
- What to test is a file because it differs every build. Contact details,
  feedback address, and the app-level description come from the environment
  beside the signing key — they are personal, and this repository is public.
- Record the ledger row after the release is cut, never before. A decision may
  be accepted, implemented, demonstrated, and reverted inside one release —
  `ADR-0017` was — so a forward-looking claim about where work will ship is a
  claim that can become false.

### Apple constraints that are not obvious

- Any build carrying the `com.apple.developer.healthkit` entitlement must
  declare `NSHealthUpdateUsageDescription`, even though this app only reads.
  The entitlement is binary and has no read-only variant, so Apple gates on
  capability rather than use. Without it every upload fails validation with
  error `90683`.
- `ITSAppUsesNonExemptEncryption` is declared `false` so no upload stops to ask
  about export compliance. The app has no networking and no custom cryptography.
- Distribution requires an App Store Connect **API key**, not an Apple ID
  app-specific password. A password authenticates the upload but cannot mint a
  distribution certificate, and this machine holds only a development identity
  — so a password alone fails at signing, before it reaches the upload.
- Internal TestFlight needs no review and is immediate. External testing — the
  only route to a public link — requires Beta App Review, roughly 24–48 hours
  on a first submission; later builds usually skip it.
- App Store Connect accepts a marketing version of literal `0`.
- The GitHub wiki's `.wiki.git` remote does not exist until one page has been
  created through the web UI.

## Precedence

When documents conflict, use this order:

1. The user's latest explicit instruction.
2. Aligned canonical requirements and accepted ADRs as one authority tier.
3. Open questions and recorded provisional defaults.
4. Proposals and proposed ADRs.
5. The historical source conversation.

If an accepted ADR and a canonical document disagree, treat it as an immediate
stop condition and fix the documentation drift before relying on either.
