# Releasing

Releases are direct downloads from GitHub, not the Mac App Store. Pushes to
`master` and pull requests run `.github/workflows/ci.yml`, which tests and
packages the app without release credentials. Pushing a tag such as `v1.2.3`
runs `.github/workflows/release.yml`, which tests the package, builds an arm64
app, signs it with a Developer ID identity, notarizes and staples the app,
packages a DMG, notarizes and staples the DMG, and publishes it with a SHA-256
checksum. See
`docs/decisions/006-github-releases.md`.

The app requires macOS 14 or later on Apple Silicon. Whisper models are not
bundled; the first run downloads the model the user chooses.

## One-time setup

1. Join the Apple Developer Program and create a **Developer ID Application**
   certificate in Certificates, Identifiers & Profiles. Install it in
   Keychain Access, select the certificate and its private key, and export
   them together as a `.p12` with a password.
2. Create an App Store Connect API key under **Users and Access →
   Integrations → App Store Connect API → Team Keys**. Give it the Developer
   role, download the `.p8` once, and note the key ID and issuer ID.
3. Add these secrets under **Settings → Secrets and variables → Actions**.
   The workflow uses a `release` environment; create it under
   **Settings → Environments** and put the secrets there if you want to limit
   which branches and tags can deploy.

   | Secret | Value |
   |---|---|
   | `DEVELOPER_ID_APPLICATION_P12` | `base64 -i DeveloperID.p12` |
   | `DEVELOPER_ID_APPLICATION_P12_PASSWORD` | password for the `.p12` |
   | `KEYCHAIN_PASSWORD` | any random password for the temporary CI keychain |
   | `APPLE_TEAM_ID` | 10-character team ID |
   | `ASC_KEY_ID` | App Store Connect API key ID |
   | `ASC_ISSUER_ID` | App Store Connect issuer ID |
   | `ASC_PRIVATE_KEY` | `base64 -i AuthKey_XXXXXXXXXX.p8` |

   `base64` output can be pasted directly; the workflow decodes it. Do not
   put the `.p12` or `.p8` files in the repository.

4. Optionally protect tags matching `v*` so only maintainers can publish.

## Cutting a release

1. Run the checks locally:

   ```sh
   swift test
   git diff --check
   ```

2. Tag the commit and push the tag:

   ```sh
   git tag -a v1.2.3 -m "Parrot Plus 1.2.3"
   git push origin v1.2.3
   ```

3. Watch the **Release** workflow. It publishes `Parrot-Plus-1.2.3.dmg` and
   `Parrot-Plus-1.2.3.dmg.sha256` on the tag's release page.

4. Verify the published download on a Mac that did not build it:

   ```sh
   spctl --assess --type open --context context:primary-signature -vvv Parrot-Plus-1.2.3.dmg
   xcrun stapler validate Parrot-Plus-1.2.3.dmg
   ```

   Then mount the DMG, drag Parrot Plus to Applications, and launch it.

## Dry run

Run **Actions → Release → Run workflow** with a version such as `1.2.3` and
leave **publish** off. The workflow signs, notarizes, and staples the app and
DMG but uploads the DMG as a workflow artifact instead of creating a release.
Turn **publish** on to create the tag and release from the selected commit.

## Local signed DMG

The local loop can build the same DMG without notarizing it:

```sh
scripts/build-app.sh 1.2.3
scripts/make-dmg.sh 1.2.3
```

`build-app.sh` uses an available Developer ID identity and otherwise ad-hoc
signs. A local DMG is useful for testing packaging; the workflow notarizes and
staples the app and DMG. To notarize a local build, set `ASC_KEY_ID`,
`ASC_ISSUER_ID`, and `ASC_PRIVATE_KEY` and run `scripts/notarize.sh` on the
app zip or DMG.

## Versioning

Tags are numeric: `v1`, `v1.2`, or `v1.2.3`. The tag, without the leading
`v`, becomes both `CFBundleShortVersionString` and `CFBundleVersion`. Do not
add prerelease suffixes until the bundle version is passed separately.

## Troubleshooting

- **Notarization fails:** the workflow prints the submission ID and the
  `notarytool log`. Common causes are an unsigned nested binary, a missing
  secure timestamp, or a certificate that is not a Developer ID Application
  certificate.
- **`security find-identity` shows no valid identity:** the `.p12` import or
  the `KEYCHAIN_PASSWORD` is wrong, or the certificate does not match
  `APPLE_TEAM_ID`.
- **The DMG is notarized but the app is blocked:** staple the DMG
  (`xcrun stapler staple`) and check that the app inside is signed with the
  same identity and a secure timestamp.
- **Permissions reset after an update:** the bundle ID, signing identity, or
  team changed. Keep `com.humanitas.parrot` and the same Developer ID team.
- **Release already exists:** delete or edit the existing release, or bump
  the version. A tag can only be released once.
