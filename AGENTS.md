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
- Keep combat mechanics independent of theme and art.
- Use primitive sci-fi shapes for MVP presentation.

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

## Precedence

When documents conflict, use this order:

1. The user's latest explicit instruction.
2. Aligned canonical requirements and accepted ADRs as one authority tier.
3. Open questions and recorded provisional defaults.
4. Proposals and proposed ADRs.
5. The historical source conversation.

If an accepted ADR and a canonical document disagree, treat it as an immediate
stop condition and fix the documentation drift before relying on either.
