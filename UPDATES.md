# Automatic updates

The app uses pinned Sparkle 2.10.1. Sparkle archive signatures do not require Apple membership, but this release pipeline deliberately requires Developer ID signing and notarization for public automatic distribution. Free ad-hoc development builds remain available; they can reset Accessibility permissions and trigger macOS trust prompts. This integration is built and tested locally, but no public release channel has been configured or published yet. The currently installed 0.2.1 app is deliberately left in place until a real feed is ready; existing users need to install the first updater-enabled release once.

## User behavior

A configured release checks for updates on launch, about hourly, and when internet connectivity returns (reconnection checks are throttled to once per hour). Offline dictation continues normally. Updates are downloaded and their Ed25519 signatures verified before extraction. The app waits for at least a minute without recording, transcription, insertion, unpasted transcript text, or an active dashboard before applying an automatic update and restarting quietly. Sparkle also installs pending updates on normal app quit. A manual Check for Updates command and an automatic-updates toggle are available. A previously downloaded update may still install on quit after automatic checking is turned off.

Speech and vocabulary remain local. Update requests contact the release host; system-profile reporting is disabled. Saved model files, vocabulary and usage data live outside the app bundle and are not replaced by updates. A transcript that has not been pasted must be copied or cleared before an automatic restart; transcripts remain memory-only.

## One-time maintainer setup

1. Put this directory at the root of your own app repository. The original `morluto/rea` repository is a separate research tool. Use a **public repository** for this workflow's unauthenticated GitHub Releases feed; a private source repository requires a separate public update host. Never embed a GitHub access token in the app.
2. Obtain a Developer ID Application certificate from your Apple Developer account and export it with its private key to a password-protected `.p12`. Use the same signing identity across releases. This avoids the unstable ad-hoc identities used by the prototype; test Accessibility retention on signed upgrades before wider distribution.
3. Resolve dependencies with `swift package resolve`. Run `.build/artifacts/sparkle/Sparkle/bin/generate_keys` once. Keep the generated private key backed up securely. Its public key is safe to publish. Export the private key to a temporary file using the tool's `-x` option, copy its contents into the GitHub secret below, then remove the temporary file. Do not paste private keys into chat or commit them.
4. Configure GitHub repository **variables**: `SPARKLE_PUBLIC_KEY` (base64 public key), `CODE_SIGN_IDENTITY` (full `Developer ID Application: …` identity), and finally `RELEASES_ENABLED=true`.
5. Configure GitHub repository **secrets**: `CERTIFICATE_P12_BASE64`, `CERTIFICATE_PASSWORD`, `SPARKLE_PRIVATE_KEY` (contents of the exported key file), `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` (app-specific password used only for notarization).
6. Protect `main` with review requirements because qualifying changes to that branch produce releases automatically. Run the release workflow manually for the first build. GitHub's hosted macOS runner must support the pinned package's Swift tools version.
7. Install the resulting release once on each existing prototype installation. Complete any initial macOS permission prompts. From that point the installed updater follows the signed feed.

The feed is `https://github.com/OWNER/REPO/releases/latest/download/appcast.xml`. The workflow derives OWNER/REPO from GitHub and embeds this URL and the public signing key during packaging. There are no placeholder URLs or private keys in the app source.

## Release process

`.github/workflows/release.yml` runs for app-related changes on `main` and on manual dispatch. Until `RELEASES_ENABLED=true`, it is intentionally disabled. It tests the app, builds for Apple Silicon and Intel, signs Sparkle's nested helpers and the app, notarizes and staples the app, signs the final ZIP using Sparkle, and independently verifies the archive signature against the public key. It creates a draft GitHub release with both archive and appcast, then publishes it so the `latest` URL changes only after both assets exist. No release is uploaded from pull-request workflows.

Build numbers are `1000 + GITHUB_RUN_NUMBER` and must remain increasing. Do not reset that sequence after shipping or reuse lower build numbers. The marketing version comes from `Resources/Info.plist`; bump it when appropriate. Keep release tags and downloadable archives immutable. Use a new higher-numbered release to roll back a faulty change.

For local release builds, provide `RELEASE_BUILD=1`, `CODE_SIGN_IDENTITY`, `APPCAST_URL`, `SPARKLE_PUBLIC_KEY`, `NOTARY_PROFILE` (a stored notarytool profile), `BUILD_NUMBER`, and optionally `APP_VERSION` / `UNIVERSAL_BUILD=1`, then run `bash scripts/build-app.sh`. `BUILD_PATH` can point to a directory outside iCloud-synced Documents. Development builds omit the feed/key and leave the updater disabled.

`publish-release.sh` requires an authenticated GitHub CLI and explicit repository, tag, commit SHA, build number and private-key file. It publishes a release, so run it only when ready to distribute. Keep the Sparkle key stable and protect release credentials. Key rotation needs a planned transition.

## Verification and remaining rollout checks

Local core tests cover configuration validation and refusing restarts during each active/unpasted-text state, alongside dictation, shortcut and vocabulary tests. The packaged development app verifies with codesign. A disposable-key test exercises actual Sparkle appcast generation and signature verification, including rejection of a modified archive.

A full installed-version-to-new-version upgrade, notarization, GitHub publishing, and permission retention still need the real repository, credentials and a configured signed release. Do that on a test Mac before inviting other users. No end-to-end production update has been claimed or performed.

References: [Sparkle setup](https://sparkle-project.org/documentation/), [configuration](https://sparkle-project.org/documentation/customization/), [publishing](https://sparkle-project.org/documentation/publishing/).
