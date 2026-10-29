# Follow the destination (v0.11.0)

Live dictation now uses the focused app after audio transcription for contextual cleanup, then captures the focused destination again immediately before paste. If the app changes during cleanup, cleanup restarts from the original transcript with the new app identity and vocabulary. Moving to a different field within the same app uses the latest field without repeating unchanged cleanup. Focus changes during modifier release are retried. Five consecutive destination changes stop automatic delivery and retain the transcript rather than loop indefinitely.

The recording-start app no longer biases live Whisper decoding: global vocabulary is used for audio transcription, and destination-specific vocabulary is applied during cleanup. This avoids carrying one app’s jargon into another. App usage is credited to the actual paste destination. Password fields remain excluded, and a missing external destination retains the transcript for copy. Recovered recordings never paste automatically; they use their saved context.

This supersedes the recording-start context and switch-app refusal descriptions in earlier documentation.
