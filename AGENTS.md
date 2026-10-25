# Agent workflow

Parrot is a single-user, local-first macOS dictation app. The local loop remains primary: improve the app and run the result on the developer's own Mac. Releases are cut from version tags by GitHub Actions.

Before changing code, read `docs/development.md`, inspect the relevant source and tests, and check `git status`. Treat the Swift source as authoritative if documentation has drifted.

## Implementation

- Keep changes focused and reuse existing types and patterns.
- Trace the full behavior path before changing persistence, permissions, startup, audio capture, or transcript delivery.
- Keep audio and transcript text local. Never add transcript text to logs, disk, analytics, or stats.
- Put testable behavior in `ParrotCore` and add or update unit tests in the matching test target.
- Update architecture or decision docs only when the change actually changes those contracts.

## Verify and run locally

- Run `swift test` for code changes and `git diff --check` before handing work back.
- To build the app bundle for local use, run `PARROT_TIMESTAMP=none scripts/build-app.sh dev`, then open `build/Parrot Plus.app`. The script uses a locally available Developer ID identity when present, otherwise ad-hoc signs the bundle.
- This writes only to the ignored `build/` directory. Do not copy the build to `/Applications` or create a global CLI link as part of the normal loop.
- Local builds are not notarized; that is unnecessary for use on this Mac. An ad-hoc build may need Microphone or Accessibility permission again after rebuilding.

## External actions

- Pushing a tag matching `v*` runs the release workflow, which signs, notarizes, and publishes a DMG; see `docs/releasing.md`. A normal branch push only sends source to GitHub.
- Do not create tags or releases, or change GitHub/Apple account settings or signing secrets, unless the user explicitly asks.
- Do not commit or push changes unless asked. Keep the handoff clear about what was tested and where the local app bundle was built.

## Shipping a release

- `master` is the default branch. CI runs on pushes to `master` and pull requests; only a `v*` tag starts a signed release.
- Read `docs/releasing.md` before a dry run or release. Never print, commit, or paste signing certificates, API keys, passwords, or secret values.
- Get explicit approval before committing, pushing, manually dispatching a release workflow, creating a tag, or publishing a release.
- For a dry run, push the approved workflow changes to `master`, then run **Release** from `master` with version `0.1.0` and `publish` off. Verify the artifact before considering a real release.
- For the first real release, get approval again, create and push annotated tag `v0.1.0`, then verify the DMG, checksum, notarization, and release page as described in `docs/releasing.md`.
