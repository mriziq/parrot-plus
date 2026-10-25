# ADR-006 :: GitHub Releases

Last updated: `2026.10.24`

## 1. Decision

- Distribute Parrot Plus as a direct download from GitHub Releases, not the
  Mac App Store.
- Pushing a tag matching `v*` runs `.github/workflows/release.yml`. A manual
  `workflow_dispatch` run can build a dry-run artifact instead.
- Release builds target Apple Silicon (`arm64`) and macOS 14 or later.
- The workflow builds the app, signs it with a Developer ID Application
  identity and hardened runtime, notarizes and staples the app, packages a DMG
  with an `/Applications` symlink, notarizes and staples the DMG, and publishes
  the DMG plus a SHA-256 checksum.
- Signing and notarization credentials live in GitHub Actions secrets; see
  `docs/releasing.md`.

## 2. Rationale

GitHub Releases is enough for a local-first app that does not need App Store
distribution. Developer ID signing plus notarization is the part that makes a
downloaded DMG open normally on another Mac; without it Gatekeeper blocks the
app and permission grants are tied to a changing ad-hoc identity.

The Mac App Store is a poor fit: Parrot needs Accessibility and a CGEventTap
for its global hotkey, and App Store sandboxing and review would conflict
with that behavior. Direct distribution keeps the existing architecture and
bundle identity.

## 3. Design Implications

- `com.humanitas.parrot` and the Developer ID team are part of the release
  identity. Changing either resets users' permission grants.
- Releases are tag-driven; branch pushes do not publish.
- The DMG does not bundle speech models. The first run downloads the selected
  model, so the release notes and README must state that an internet
  connection is needed on first use.
- Updates are manual downloads until an auto-update mechanism is added.
- A release requires an Apple Developer Program membership and a Developer ID
  Application certificate.

## 4. When to Revisit

- Adding Sparkle or another auto-update mechanism.
- Supporting Intel Macs or a different minimum macOS version.
- Changing the distribution channel or bundle identity.
