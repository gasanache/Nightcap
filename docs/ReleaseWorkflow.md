# Release Workflow

This document describes how to cut a release of the Nightcap app and how to publish a new Wine Libraries archive.

The fork uses two parallel artifact streams:

- **App releases** (`app-vX.Y.Z`) — `Nightcap-X.Y.Z.dmg`, signed and notarized for direct distribution.
- **Wine Libraries releases** (`vX.Y.Z`) — `Libraries.tar.gz` containing the Wine/DXVK runtime that the app downloads on first launch.

Both live on GitHub Releases. Static metadata (the Wine version plist) is served from GitHub Pages, which is **workflow-deployed** through `.github/workflows/Documentation.yml`. The `gh-pages` branch is unused; static files go in `dist/pages/`.

Nightcap has **no auto-update mechanism**: no Sparkle, no update feed, no in-app updater. A new version is installed by downloading the DMG or through the Homebrew cask.

## One-time setup

These only need to be done once per maintainer machine.

### Apple Developer ID Application certificate

A Developer ID Application certificate is required to ship a Gatekeeper-friendly DMG. Apple Development and Apple Distribution certs are not sufficient.

1. **Xcode → Settings → Accounts** → select your Apple ID → **Manage Certificates…**
2. Click **+** → **Developer ID Application**
3. The cert is installed in your login keychain automatically.

### notarytool credentials

Apple's notary service needs an app-specific password.

1. Generate one at <https://appleid.apple.com> → **Sign-In and Security → App-Specific Passwords**.
2. Store it as a notarytool keychain profile:
   ```sh
   xcrun notarytool store-credentials AC_PASSWORD \
     --apple-id <your-apple-id-email> \
     --team-id Z7JS58F8U3 \
     --password <app-specific-password>
   ```
3. The release script reads this profile by name (`AC_PASSWORD`).

## Credential continuity (backup & recovery)

Two secrets gate the release pipeline. Keep current, restore-tested backups of both. (A third credential, the `BREW_TOKEN` repository secret used by the release step that publishes to [frankea/homebrew-nightcap](https://github.com/frankea/homebrew-nightcap), is regenerable and so needs no backup — the focus here is on the non-regenerable ones.)

| Secret | Where it lives | If lost |
| --- | --- | --- |
| Developer ID Application identity | login keychain | Re-issue from the Apple Developer portal; releases blocked until done |
| notarytool app-specific password | appleid.apple.com; cached as keychain profile `AC_PASSWORD` | Regenerate at appleid.apple.com, re-run `store-credentials` |

### Backup procedure

1. Export the Developer ID identity: **Keychain Access → My Certificates** → right-click *Developer ID Application: …* → **Export** as `.p12` with a strong password.
2. Encrypt it before it leaves the machine:

   ```sh
   age -p developer_id.p12 > developer_id.p12.age   # or: gpg -c developer_id.p12
   ```

   Neither `age` nor `gpg` ships with macOS; install `age` with `brew install age`.

3. Store the encrypted file — plus the app-specific password itself — in **two** off-machine locations (e.g. a password-manager secure note and one offline medium). Delete the plaintext export afterwards.
4. Record the certificate expiry date and set reminders at T-60 and T-14 days:

   ```sh
   security find-certificate -c "Developer ID Application" -p | openssl x509 -noout -enddate
   ```

   This prints the first matching certificate only. During a renewal window, when the
   old and new certificates coexist in the keychain, check every match with
   `security find-certificate -a -c "Developer ID Application" -p` (each `-----BEGIN`
   block is one certificate) — and re-run this step after the renewal so the reminder
   tracks the new expiry, not the old one.

### Restore test (do this the day the backup is made)

A backup that has never been restored from is a hope, not a backup. Decrypt the archived `.p12` on the spot and confirm it opens with the recorded password and carries the identity you expect:

```sh
age -d developer_id.p12.age > restore-test.p12
openssl pkcs12 -in restore-test.p12 -nokeys -legacy | openssl x509 -noout -subject -enddate
rm restore-test.p12
```

The printed subject must be the *Developer ID Application* identity releases are signed with, and the expiry must match the date recorded above. A prompt that rejects the password, or a subject that isn't that identity, means the backup is not usable — redo it. Delete the decrypted `.p12` as soon as the check passes.

### Recovery on a new machine

1. Decrypt the backup: `age -d developer_id.p12.age > developer_id.p12`, entering the backup passphrase.
2. Open the `.p12` to install the Developer ID identity into the login keychain, then delete the decrypted file.
3. Re-create the notary profile with `xcrun notarytool store-credentials AC_PASSWORD …` (see One-time setup).

## App release

### 1. Bump versions

Update both fields in `Nightcap.xcodeproj/project.pbxproj` (every occurrence):

- `MARKETING_VERSION = X.Y.Z;` — user-visible version.
- `CURRENT_PROJECT_VERSION = N;` — build number, must increment monotonically.

### 2. Update the changelog

Move items from `[Unreleased]` to a new `[X.Y.Z] - YYYY-MM-DD (App)` section in `CHANGELOG.md`.

### 3. Build, sign, notarize, package

```sh
scripts/release.sh X.Y.Z
```

The script:

1. Archives the app (Apple Development signing during archive — automatic provisioning handles cert resolution).
2. Re-signs on export with **Developer ID Application** per `scripts/exportOptions.plist`.
3. Verifies the signature with `codesign --verify --deep --strict`.
4. Builds a UDZO disk image with `hdiutil`.
5. Signs the DMG with the Developer ID Application certificate.
6. Submits the DMG to Apple's notary service and waits for the verdict (typically 5–15 minutes).
7. Staples the notarization ticket.
8. Verifies the stapled DMG passes `spctl --assess`.

The artifact lands at `build/release/Nightcap-X.Y.Z.dmg`.

### 4. Commit, tag, and release

```sh
git add Nightcap.xcodeproj/project.pbxproj CHANGELOG.md
git commit -m "release: X.Y.Z"
git push
git tag -a app-vX.Y.Z -m "Nightcap X.Y.Z"
git push origin app-vX.Y.Z

gh release create app-vX.Y.Z \
  --repo frankea/Nightcap \
  --title "Nightcap X.Y.Z" \
  --notes "..." \
  build/release/Nightcap-X.Y.Z.dmg
```

Existing installs are not notified: there is no update feed. Users pick the new version up from the release page or the Homebrew cask.

### 5. Homebrew tap (automatic)

Publishing the `app-vX.Y.Z` release fires `.github/workflows/UpdateHomebrewTap.yml`,
which downloads the DMG, computes its sha256, and bumps the
[frankea/homebrew-nightcap](https://github.com/frankea/homebrew-nightcap) cask so
`brew install --cask frankea/nightcap/nightcap` tracks the new version. No manual edit needed.

This requires a one-time repository secret **`BREW_TOKEN`** — a personal access token
(classic `repo`, or fine-grained with **Contents: write**) for `frankea/homebrew-nightcap`;
the default `GITHUB_TOKEN` cannot push to another repository. If the secret is missing the
workflow fails loudly so the drift is visible. You can also re-sync any tag manually via the
workflow's `workflow_dispatch` input.

## Wine Libraries release

The runtime (`Libraries.tar.gz`) is **assembled from upstream binaries, not built from source** — see
[`DEPENDENCIES.md`](DEPENDENCIES.md) for the authoritative list of components,
their pinned versions, and where each comes from. When the runtime needs to change:

1. **Assemble `Libraries.tar.gz`** from the pinned upstream binaries. The archive unpacks to a
   `Libraries/` tree the app expects (`Libraries/Wine/bin/…` is the Wine binary dir per
   `NightcapWineInstaller.binFolder`). To reproduce a build:
   - Download the pinned **Wine** build (Gcenx `macOS_Wine_builds`) and unpack it as `Libraries/Wine/`.
   - Add the pinned **DXVK-macOS** DLLs and **DXMT** prebuilt release into the runtime per the Gcenx
     layout.
   - Place **D3DMetal** as extracted from Apple's Game Porting Toolkit. ⚠️ Redistribution is governed by
     Apple's GPTK license — confirm terms before publishing.
   - Record the exact versions you used back into `docs/DEPENDENCIES.md`, and bump the matching
     `*_PINNED` tags in `.github/workflows/RuntimeTrack.yml` so drift detection stays accurate.
   - `tar -czf Libraries.tar.gz Libraries/` (mind the `Tar` pipe-drain pitfall noted below).
2. Tag with the bare version `vX.Y.Z` (no `app-` prefix).
3. `gh release create vX.Y.Z --title "Wine Libraries vX.Y.Z" Libraries.tar.gz`.
4. Compute the SHA-256 of the **exact published asset** — the app verifies the download against this
   and fails closed on a mismatch, so an incorrect value blocks every fresh install:
   ```sh
   shasum -a 256 Libraries.tar.gz
   ```
5. Update `dist/pages/WhiskyWineVersion.plist` with the version, bundled DXVK version, and the digest
   from the previous step. Record the same digest in [`DEPENDENCIES.md`](DEPENDENCIES.md):
   ```xml
   <dict>
       <key>version</key>
       <dict>
           <key>major</key><integer>X</integer>
           <key>minor</key><integer>Y</integer>
           <key>patch</key><integer>Z</integer>
       </dict>
       <key>dxvkVersion</key>
       <string>1.10.3</string>
       <key>sha256</key>
       <string>…64-hex-digest…</string>
   </dict>
   ```
6. Commit and push. The Documentation workflow republishes Pages, and existing app installs prompt to update on their next Wine version check.

## URLs the app depends on

- `https://frankea.github.io/Whisky/WhiskyWineVersion.plist` — Wine version metadata
- `https://github.com/frankea/Whisky/releases/download/vX.Y.Z/Libraries.tar.gz` — Wine binary archive
- `https://github.com/frankea/Whisky/releases/download/app-vX.Y.Z/Nightcap-X.Y.Z.dmg` — app DMG

## Pitfalls

- **Don't override `CODE_SIGN_IDENTITY` at archive time.** The project is configured for Apple Development with automatic signing; overriding it conflicts with provisioning. The release script lets `xcodebuild archive` use the project default and re-signs on export.
- **Don't bundle the NightcapKit folder as Resources.** Doing so packages the package's `.build` directory (DocC plugin executables) into the app, and Apple's notary rejects the archive because those plugin executables don't have hardened runtime. The PBXResourcesBuildPhase entry for `NightcapKit` was removed from the project for this reason; do not add it back. The PBXFileReference and PBXGroup entries must remain or Xcode's SPM workspace integration crashes on CI.
- **Pipe deadlocks in `Tar`.** `process.waitUntilExit()` must come *after* draining the pipe, not before. The verbose tar listing for a multi-hundred-megabyte archive will overflow the OS pipe buffer. See the fix in 3.0.1.
