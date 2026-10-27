# App-aware dictation

Version 0.7.0 uses the target application category captured at recording start as a weak spelling hint for local smart cleanup. Enable or disable it in Controls → Smart cleanup → Use target app context.

Terminal, iTerm2, Warp, Ghostty, Kitty and Alacritty receive terminal context. VS Code, Cursor, Xcode, Zed, Sublime Text, Atom, Windsurf, Codex and JetBrains apps receive coding context. Unknown apps and browsers use general writing context; browser websites are not inspected.

The local model considers sentence meaning as well as the category: “run the database cedar” can become “run the database seeder,” while “the cedar tree is tall” stays unchanged. This is probabilistic disambiguation, not a global replacement dictionary. Preferred vocabulary remains available for names and specialist terms.

No screen text, window titles, documents or clipboard contents are read for this feature. Only the category is saved with retained recording metadata so retries use the original context. Old recordings without context use general writing. Disabling context also disables it for retries. Smart cleanup and an available Apple Intelligence model are required. Whisper transcription itself is unchanged. Original transcripts remain available for comparison and restoration. Context never generates or executes terminal commands.
