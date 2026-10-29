# Local Dictation

Open-source macOS 14+ dictation with local Whisper Large v3 Turbo inference. Optimized and tested on Apple silicon; the build pipeline also produces an Intel binary. Intel runtime performance has not been validated.

## Everyday use

- **Background:** close the dashboard and keep dictating. The menu-bar waveform opens the dashboard or quits the app. No Dock icon is needed.
- **Floating control:** drag the minimal floating pill to any screen edge; it snaps and remembers its position. Right-click for explicit edge choices or recording mode. It remains above other apps without taking keyboard focus.
- **Push to talk:** hold Fn while speaking, then release to transcribe and paste.
- **Hands-free:** press Fn+Space to start or latch a held recording; press Fn once to finish. Click the floating icon to start hands-free recording.
- **Toggle mode:** choose Controls → Toggle. Tapping Fn then starts/stops recording.
- **Fallback shortcut:** Control–Option–Space follows the selected recording mode.
- **Finish/cancel:** the floating waveform uses live microphone metering. Click ✓ to finish or × / Escape to discard. A recording stops after 10 minutes. Cancellation requests decoder cancellation and discards its eventual result. Once paste submission starts it cannot be cancelled.

Fn handling requires Accessibility permission and may conflict with macOS's Globe-key action or another dictation app. Set the Globe-key action to “Do Nothing” in macOS Keyboard settings if necessary. The app does not change system keyboard settings. Quit or reconfigure other apps using Fn. If macOS requests Input Monitoring, grant it to use Fn, or use the fallback shortcut.

## Custom shortcuts and spoken edits

Controls → Keyboard shortcuts lets you choose independent key/modifier combinations for push-to-talk and hands-free dictation. Hold push-to-talk to record and release to finish; press hands-free to start or finish. The defaults are Control–Option–Space and Control–Option–R. Fn / Fn+Space can remain enabled alongside them, or be disabled. Save applies and persists changes; registration conflicts restore the previous shortcuts. System-reserved shortcuts may need a different combination.

With Smart cleanup enabled, “scratch the last line/sentence,” “delete the last word,” “delete the last paragraph,” “scratch that,” and “start over” edit the current recording before paste. A “line” means the preceding sentence because dictation has no visual line wrapping yet. Apple Intelligence also interprets explicit corrections such as “actually make that Tuesday” or “replace Monday with Tuesday” as anchored replacements of earlier wording. Say formatting requests naturally to change the layout. Quoted or reported commands are preserved; ambiguous or unsupported instructions can remain literal. This does not edit text already pasted into another app or perform external actions. The original transcript and recent audio remain available for recovery.

The active recording panel is larger, with wider, taller bars and a speech-oriented microphone level scale. The idle pill keeps its compact size.

## Automatic paste

Enable Accessibility for Local Dictation in System Settings → Privacy & Security. After a development update, macOS may require removing and re-adding the app or toggling its permission, then restarting it.

Put the cursor in the destination field before recording. The floating control preserves focus. Starting from the dashboard returns to the most recently active external app. Automatic insertion uses the destination app's paste shortcut, including apps that do not expose an accessibility text field. Moving to another app/window or a detectable different editable field prevents paste. Without a usable AX field, the app can verify the destination app/window but cannot prove that the cursor stayed in the same field. Known password fields are excluded.

The clipboard is temporarily populated, then restored after 900 ms if no other app changed it. Clipboard managers can retain the pasted text. “Paste in last app” explicitly sends the editable latest transcript to the last external app. “Paste sent” confirms event delivery, not that every third-party app accepted the text.

## Smart cleanup

After transcription, the app edits spelling, grammar and punctuation, removes filler and false starts, and formats spoken lists before pasting. Lists, ordered steps, paragraphs and short headings are inferred from the content without requiring spoken commands. Explicit requests such as “bullet points” or “new paragraph” are also honored. “So” is treated as a contextual transition, not an unconditional list command. Output uses plain text bullets and numbers so it works across apps. Controls → Smart cleanup turns this step on or off; it is on by default.

Cleanup has a shared 2.5-second budget per dictation, including destination-app changes. If the budget expires, the app cancels remaining model work and uses the latest validated text, preserving completed edits and the rest of the transcript. Incomplete formatting or context corrections may be skipped; the dashboard marks this as Quick paste. Late model results never replace already-pasted text. This budget excludes speech decoding and waiting for shortcut modifiers to be released.

Cleanup uses Apple's on-device Foundation Models on macOS 26+ with Apple Intelligence enabled and its model ready. It needs no API key or cloud transcription service. Other Macs retain ordinary local dictation. If cleanup is unavailable, fails, drops substantial content or the ending, or changes protected literal numbers, URLs or email addresses, the original transcript is used. AI edits are not guaranteed to preserve every nuance; the dashboard retains the original transcript for comparison and restoration. Neither version is saved to disk. Statistics count original spoken words.

Vocabulary spellings also guide cleanup. Long transcripts are edited in small independent sections, so formatting across section boundaries may need adjustment.

## Dashboard and vocabulary

Statistics show real completed dictations: total words, today's words, recording WPM, word-count and pace charts, time on mic, and a 26-week activity heat map. WPM is total words divided by recording minutes, including pauses. Counts begin with this version; old usage is not estimated. Empty/cancelled recordings do not count. A successfully transcribed recording counts even if paste fails.

Vocabulary entries supply recognition hints to local Whisper. Add names, jargon, or phrases, and optionally specify a recurring misrecognition to replace. Explicit corrections match whole words/phrases, case-insensitively, in one pass. Hints are bounded to 80 entries / 200 tokens. Vocabulary bias is not fine-tuning and cannot guarantee recognition. Entries can be edited or deleted.

## Data and offline behavior

The app stores counts, durations, dates, and vocabulary in `~/Library/Application Support/LocalDictation/usage.json`. Transcripts are kept in memory only. Audio is saved in `~/Library/Application Support/LocalDictation/Recordings` for recovery. The folder is restricted to the current user. Up to 30 recordings are retained for 24 hours; cleanup runs on launch, before capture, and every minute while idle. When the app is closed, expired files are removed the next time it runs. Transcripts remain in memory only.

Failed transcription gets up to three attempts. Pending recordings are processed again on launch, and Overview → Recent recordings offers Retry, Delete, and Open folder. Recovery results stay in the dashboard rather than automatically pasting into a new destination. Retrying a completed recording does not add its words to statistics again. Explicit cancellation deletes that recording. Normal quit preserves unfinished audio; recovery after a forced crash depends on whether macOS finalized a readable audio file.

Speech decoding uses timestamps and voice-activity-based chunking, processes the final short fragment, and adds silent padding to protect the ending. These measures reduce truncation but cannot guarantee perfect recognition. The raw transcript remains accessible if AI cleanup changes wording. A partial but plausible recognition result may not be detectable automatically; use the saved recording to retry.

Download the multilingual Whisper Large v3 Turbo model once using Controls (approximately 627 MB, plus tokenizer files). This uses the compressed Core ML model and its matching Turbo tokenizer. Upgrading from Base requires this one-time download; existing Base files are left untouched. Model and tokenizer files are downloaded from Hugging Face. Speech inference runs locally with no speech API, analytics, or account. WhisperKit may attempt to fetch a tokenizer if local assets are corrupt; speech is not uploaded. The supported model path has been exercised with all networking denied.

## Build

```sh
# Use Xcode 26+ to include on-device smart cleanup.
bash scripts/build-app.sh
open "dist/Local Dictation.zip"
```

Extract the archive, move Local Dictation.app to Applications, and open it. Packaging uses a temporary directory to prevent synced-folder metadata from invalidating signatures. The bundle is ad-hoc signed for development; distribution requires your own signing identity and notarization.

```sh
swift test -c release
.build/release/LocalDictation --prepare-model
.build/release/LocalDictation --transcribe /absolute/path/to/sample.wav
.build/release/LocalDictation --polish-text /absolute/path/to/transcript.txt
```

Automated tests cover text cleanup, silence detection, shortcuts, vocabulary, statistics and update restart policy. Physical keyboard behavior and signed upgrades also need testing on target Macs. The app is an original implementation; it contains no copied Wispr implementation. Streaming partial transcripts, login launch, and Wispr feature/quality parity are not implemented.

## 0.2.1 refinements

The idle overlay is now a 34 × 14 point pill that fades when not hovered. Recording expands it into compact waveform controls. Quiet start/stop chimes can be disabled in Controls. After Fn + Space starts hands-free recording, press Fn once to finish; its release does not start another session.

## Automatic update distribution

The 0.3.0 source integrates Sparkle and includes a signed GitHub Releases pipeline. A configured public feed and release credentials are required before updates can go live. See [UPDATES.md](UPDATES.md) for setup, release behavior, and rollout checks. Existing 0.2.x installs need a one-time manual installation of the first configured release.

## License

MIT; see [LICENSE](LICENSE). Bundled third-party components retain their licenses in `Resources/Licenses`. This project is independently developed and is not affiliated with Wispr Flow.
