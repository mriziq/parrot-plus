# ADR-005 :: Signed app identity

Last updated: `2026.09.27`

> This ADR records the inherited app-identity decision. This local-development fork keeps bundle ID `com.humanitas.parrot` and `SMAppService`; public release signing, notarization, and automatic updates described in the original implementation are not part of this repo's workflow.

## 1. Decision

- **Bundle ID `com.humanitas.parrot`.** The local app bundle uses this stable identifier.
- **Local signing.** `scripts/build-app.sh` uses an available Developer ID identity or falls back to ad-hoc signing. The local app is not notarized.
- **`SMAppService` for launch at login**, replacing the hand-written LaunchAgent (label `com.digimata.parrot`), which is removed on upgrade.
- **One binary, two roles.** The executable inside the bundle runs the dictation loop when launched with no subcommand and serves the CLI through a symlink.

## 2. Rationale

macOS keys TCC grants to the code identity. A stable bundle ID and Developer ID identity can preserve permissions between local builds when that identity is available; ad-hoc builds may require the user to grant permissions again.

`com.digimata.parrot`, the LaunchAgent's label, was rejected in favour of the current bundle identity. Changing a bundle ID after permissions are granted can require new permission grants, so the stable identifier remains useful for local testing.

## 3. Design Implications

- Changing the bundle ID or signing team resets every user's permission grants; treat it as a breaking change.
- Local builds can run directly from `build/Parrot Plus.app`; no update or release service is configured.
- The running app asks for its own grants on first start and waits for them; it never exits over a missing Accessibility grant.

## 4. When to Revisit

- A change to the bundle ID or local signing approach.
