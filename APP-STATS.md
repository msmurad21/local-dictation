# App usage statistics (v0.10.0)

Apps now includes total apps, dictations and words; a 14-day daily words chart; and per-app word share, dictations, words, and fixed recording duration. Apps are ranked by words. Last used is an explicitly labeled fixed local date/time, replacing the live relative-time display that looked like an ongoing recording timer.

Existing app totals are preserved. Daily events and per-app recording time start with this update; unknown historical durations display a dash, not zero. Durations come from the saved audio recording, excluding transcription/cleanup/paste wait time. Manual pastes retain the recording identity and duration. Repeated pastes of the same recording into the same app do not inflate statistics; pasting into a different app counts for that destination.

Usage is recorded when the app sends a paste, not by reading back another app’s text. These are Local Dictation usage metrics, not foreground screen-time tracking. All history remains local.
