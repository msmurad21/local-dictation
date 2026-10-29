# Interface and shortcuts (v0.9.0)

Fn is always push-to-talk. Fn + Space starts hands-free recording; Fn finishes it. Controls offers Record shortcut for an optional custom hold shortcut and an optional custom hands-free shortcut. Press a key with Command, Option or Control. Escape cancels capture; leaving the app cancels capture too. Conflicting registrations produce an error without replacing the previous shortcut. The reset arrow removes the custom shortcut. Fn shortcuts remain available. This update removes the old default Control–Option shortcuts and migrates to the Fn-first interface.

Controls uses custom button and switch styles, with concise sections for recording, comfort and cleanup. Apps shows per-app dictation counts and words after a paste event has been sent, using locally stored app identities. This is not confirmation that another app accepted the paste; no text is read back. Old usage records have no app identity and are not backfilled. Existing statistics and vocabulary remain intact.

The destination is captured from the system accessibility focused application and focused UI element's owning process, with the frontmost app as fallback when accessibility information is unavailable. Field contents are not read. Focus is still revalidated before paste; switching apps or editable fields retains the transcript for manual copy rather than silently sending it elsewhere.

AppIcon.icns contains all required macOS icon sizes, is declared in Info.plist, is copied by the build script and is loaded as the running application icon. Regenerate with scripts/make-icon.swift and iconutil.
