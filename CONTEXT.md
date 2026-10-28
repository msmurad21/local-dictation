# App-aware dictation

Version 0.8.0 captures the exact target app name, bundle identifier, category and vocabulary at recording start. Controls → Smart cleanup shows the last captured target, and lets you enable or disable app context.

App vocabulary: switch to your target app, return to Controls, enter comma-separated jargon and save. These terms apply only to that app. Global Vocabulary still applies everywhere and is prioritized. Built-in vocabulary profiles cover Xcode, JetBrains language IDEs, SQL clients and Figma; other recognized coding and terminal apps receive broad technical vocabulary. Unknown apps retain their exact identity as a weak domain hint, without fabricated default terms. Browser sites and document contents are not inspected.

Both Whisper recognition and Apple Intelligence cleanup receive relevant terms. A local-model spelling step proposes corrections to known vocabulary; only bounded, sound-alike, exact-span edits are accepted. Quoted words, paths and ambiguous repeated spans are protected. This is probabilistic disambiguation, not a replacement dictionary or a guarantee of perfect jargon recognition. The cleanup model must be available for contextual post-processing; speech vocabulary hints work independently.

App identity and the vocabulary snapshot are stored locally alongside the retained recording metadata so retries use the same context. Old recordings without a snapshot fall back to category/general context. Disabling context also disables it for retries. No screen, document, window-title or clipboard text is read for context. Original transcripts remain available for comparison and restoration. Context does not generate or execute terminal commands.

The floating active panel is restored to its original 230 × 54 size, with a 30-point maximum waveform height and stronger meter response. Elapsed time is available on hover and via accessibility instead of taking waveform space.
