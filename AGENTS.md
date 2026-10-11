# Agent workflow

Parrot is a single-user, local-first macOS dictation app. The goal here is to improve the app and run the result on the developer's own Mac, not to publish public releases.

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

- This repo has no publishing or release workflow. A normal branch push only sends source to GitHub; local use still comes from `build/Parrot Plus.app`.
- Do not notarize an app or change GitHub/Apple account settings unless the user explicitly asks.
- Do not commit or push changes unless asked. Keep the handoff clear about what was tested and where the local app bundle was built.
