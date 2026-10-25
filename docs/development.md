# Local development

The working loop is local: change a feature, test it, build the app bundle, and run that bundle on this Mac. Releases are cut separately by pushing a version tag; see [releasing.md](releasing.md).

## Feature loop

1. Check the current branch and `git status`; preserve any existing work.
2. Read the relevant code and tests before editing. `docs/architecture.md` describes the intended boundaries; verify details against the current source.
3. Keep the change scoped and add tests for behavior that can be exercised without system permissions.
4. Run the tests and build a local app bundle:

   ```sh
   swift test
   git diff --check
   PARROT_TIMESTAMP=none scripts/build-app.sh dev
   ```

5. Run the built copy directly:

   ```sh
   open "build/Parrot Plus.app"
   ```

The app bundle is created at `build/Parrot Plus.app`, which is ignored by Git. This does not install over another app, add a CLI symlink, or publish anything. The build script uses a locally available Developer ID identity when present and otherwise ad-hoc signs the bundle.

The local bundle is not notarized; notarization is only needed to distribute the app to other Macs. macOS may ask for Microphone and Accessibility permissions. With ad-hoc signing it may ask again after a rebuild because the code identity changes.

## Release boundary

Pushes to `master` and pull requests run `.github/workflows/ci.yml`, which tests the package and verifies local-style app and DMG packaging without secrets. Pushing a tag matching `v*` runs `.github/workflows/release.yml`, which tests, builds, signs, notarizes, and publishes a DMG on GitHub Releases. Local use still comes from `build/Parrot Plus.app`; the release workflow is documented in [releasing.md](releasing.md).

## Code map

- `Sources/ParrotCore/` contains app behavior, organized by app, input, audio, transcription, pipeline, settings, and UI.
- `Sources/parrot/` is the executable entry point and CLI.
- `Sources/parrot-bench/` contains developer-only benchmarks.
- `Tests/ParrotTests/` and `Tests/ParrotBenchTests/` contain the Swift package tests.
- `scripts/build-app.sh` assembles and signs the `.app` bundle; it is reused for the local build above.
- `scripts/make-dmg.sh` packages the built app into a DMG for distribution.
- `scripts/notarize.sh` submits an app zip or DMG to Apple's notary service.
- `.github/workflows/release.yml` runs the tag-driven release build, signing, notarization, and GitHub release.
