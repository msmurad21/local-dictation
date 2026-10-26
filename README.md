# Local Dictation

Open-source macOS 14+ dictation with local Whisper Base inference. Optimized and tested on Apple silicon; the build pipeline also produces an Intel binary. Intel runtime performance has not been validated.

## Everyday use

- **Background:** close the dashboard and keep dictating. The menu-bar waveform opens the dashboard or quits the app. No Dock icon is needed.
- **Floating control:** drag the minimal floating pill to any screen edge; it snaps and remembers its position. Right-click for explicit edge choices or recording mode. It remains above other apps without taking keyboard focus.
- **Push to talk:** hold Fn while speaking, then release to transcribe and paste.
- **Hands-free:** press Fn+Space to start or latch a held recording; press Fn once to finish. Click the floating icon to start hands-free recording.
- **Toggle mode:** choose Controls → Toggle. Tapping Fn then starts/stops recording.
- **Fallback shortcut:** Control–Option–Space follows the selected recording mode.
- **Finish/cancel:** the floating waveform uses live microphone metering. Click ✓ to finish or × / Escape to discard. A recording stops after 10 minutes. Cancellation during decoding discards its eventual result; it does not interrupt the model mid-inference. Once paste submission starts it cannot be cancelled.

Fn handling requires Accessibility permission and may conflict with macOS's Globe-key action or another dictation app. Set the Globe-key action to “Do Nothing” in macOS Keyboard settings if necessary. The app does not change system keyboard settings. Quit or reconfigure other apps using Fn. If macOS requests Input Monitoring, grant it to use Fn, or use the fallback shortcut.

## Automatic paste

Enable Accessibility for Local Dictation in System Settings → Privacy & Security. After a development update, macOS may require removing and re-adding the app or toggling its permission, then restarting it.

Put the cursor in the destination field before recording. The floating control preserves focus. Starting from the dashboard returns to the most recently active external app. Automatic insertion uses the destination app's paste shortcut, including apps that do not expose an accessibility text field. Moving to another app/window or a detectable different editable field prevents paste. Without a usable AX field, the app can verify the destination app/window but cannot prove that the cursor stayed in the same field. Known password fields are excluded.

The clipboard is temporarily populated, then restored after 900 ms if no other app changed it. Clipboard managers can retain the pasted text. “Paste in last app” explicitly sends the editable latest transcript to the last external app. “Paste sent” confirms event delivery, not that every third-party app accepted the text.

## Dashboard and vocabulary

Statistics show real completed dictations: total words, today's words, recording WPM, word-count and pace charts, time on mic, and a 26-week activity heat map. WPM is total words divided by recording minutes, including pauses. Counts begin with this version; old usage is not estimated. Empty/cancelled recordings do not count. A successfully transcribed recording counts even if paste fails.

Vocabulary entries supply recognition hints to local Whisper. Add names, jargon, or phrases, and optionally specify a recurring misrecognition to replace. Explicit corrections match whole words/phrases, case-insensitively, in one pass. Hints are bounded to 80 entries / 200 tokens. Vocabulary bias is not fine-tuning and cannot guarantee recognition. Entries can be edited or deleted.

## Data and offline behavior

The app stores counts, durations, dates, and vocabulary in `~/Library/Application Support/LocalDictation/usage.json`. Transcripts are kept in memory only. Temporary recordings are deleted after processing or normal shutdown; a crash or forced quit can leave a temporary WAV.

Download the multilingual Base model once using Controls. Model and tokenizer files are downloaded from Hugging Face. Speech inference runs locally with no speech API, analytics, or account. WhisperKit may attempt to fetch a tokenizer if local assets are corrupt; speech is not uploaded. The supported model path has been exercised with all networking denied.

## Build

```sh
bash scripts/build-app.sh
open "dist/Local Dictation.zip"
```

Extract the archive, move Local Dictation.app to Applications, and open it. Packaging uses a temporary directory to prevent synced-folder metadata from invalidating signatures. The bundle is ad-hoc signed for development; distribution requires your own signing identity and notarization.

```sh
swift test -c release
.build/release/LocalDictation --prepare-model
.build/release/LocalDictation --transcribe /absolute/path/to/sample.wav
```

Automated tests cover text cleanup, silence detection, shortcuts, vocabulary, statistics and update restart policy. Physical keyboard behavior and signed upgrades also need testing on target Macs. The app is an original implementation; it contains no copied Wispr implementation. Semantic rewriting, streaming partial transcripts, login launch, and Wispr feature/quality parity are not implemented.

## 0.2.1 refinements

The idle overlay is now a 34 × 14 point pill that fades when not hovered. Recording expands it into compact waveform controls. Quiet start/stop chimes can be disabled in Controls. After Fn + Space starts hands-free recording, press Fn once to finish; its release does not start another session.

## Automatic update distribution

The 0.3.0 source integrates Sparkle and includes a signed GitHub Releases pipeline. A configured public feed and release credentials are required before updates can go live. See [UPDATES.md](UPDATES.md) for setup, release behavior, and rollout checks. Existing 0.2.x installs need a one-time manual installation of the first configured release.

## License

MIT; see [LICENSE](LICENSE). Bundled third-party components retain their licenses in `Resources/Licenses`. This project is independently developed and is not affiliated with Wispr Flow.
