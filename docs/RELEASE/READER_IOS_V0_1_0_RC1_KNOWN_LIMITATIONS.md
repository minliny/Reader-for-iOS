# Reader-iOS v0.1.0-rc1 Known Limitations

## Search E2E

- Real online search requires user-provided book source JSON
- Most Chinese book source sites are JS-rendered or have anti-bot protection
- IOS-4A-NET-001 / IOS-5A-NET-001 DEFERRED

## Local Book

- TXT import: file selection works, parser available in Core
- EPUB import: ZIP/XML parsing not in Core (adapter scope)
- No batch import

## Sync/WebDAV

- WebDAV settings UI exists, but real WebDAV client is adapter scope
- Progress sync UI exists, conflict resolution wired
- No real cloud sync without adapter implementation

## JS/WebView

- Production WebView adapter exists for WKWebView
- JS-runtime-dependent sites not supported (S26.6 locked in Core)

## Platform

- Keychain: credential storage works
- Background sync: scheduler protocol defined, real implementation pending
- File access: protocol defined, scoped-resource implementation pending
