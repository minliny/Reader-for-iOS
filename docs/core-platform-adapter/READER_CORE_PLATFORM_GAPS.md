# Reader-Core Platform Gap Notes - iOS

Snapshot date: 2026-06-23

This document records iOS-owned gaps for Reader-Core platform evidence. It is a
host-repo document only and does not modify Reader-Core gates.

## Current Host Evidence

| Area | Current state | Evidence path |
| --- | --- | --- |
| Host runtime evidence export | Descriptor/exporter exists | `iOS/CoreBridge/HostRuntimeEvidenceExporter.swift` |
| Debug WebView autorun manifest | WebView autorun writes `host_runtime_evidence_manifest.json` when it runs | `iOS/Features/Debug/WebViewRuntimeAutorunView.swift` |
| Redaction tests | Focused tests exist, but full `swift test` is blocked by unrelated app-source availability issues | `iOS/Tests/ShellSmokeTests/HostRuntimeEvidenceExporterTests.swift` |

## Remaining Gaps

| Gap | Owner | Current blocker | Required close evidence |
| --- | --- | --- | --- |
| S3 local book handoff | iOS host app | UIDocumentPicker/fileImporter security-scoped access has descriptor support, but no fresh platform smoke report is attached here | `local_book_security_scoped_handoff_manifest.json` from simulator/device run |
| S5 WKWebView DOM smoke | iOS Debug Harness / platform runtime | Manifest export is wired, but no successful fresh WKWebView run is recorded in this document | `host_runtime_evidence_manifest.json` plus redacted `webview_result.json` |
| S5 WebView/HTTP cookie mirror | iOS platform runtime | Cookie mirror metadata path is not implemented as measured evidence | `webview_cookie_mirror_audit` with metadata-only cookie summary |
| S5 login/session | iOS host UI + WKWebView | Real website login requires explicit operator approval and redacted fixture policy | `session_cookie_login_platform_runner` with no raw cookie, password, token, or HTML body |
| S5 credential boundary | iOS Keychain / access group | Production Keychain access-group smoke is not attached | `secure_storage_platform_audit` and `credential_redaction_revocation_matrix` |
| S10 release intake | Product governance + CI | iOS can emit evidence, but cannot mutate Reader-Core `production_release` | CI artifact, operator approval, and external evidence ledger entry |

## Non-Goals

- Do not copy, translate, or adapt Legado Android implementation code.
- Do not store raw cookie values, credentials, authorization headers, query strings, HTML bodies, local file paths, or private book content.
- Do not mark Reader-Core release gates as passed from this repository.
- Do not expand iOS shell code into Reader-Core parser/runtime implementation.

## Next Small iOS Slice

Run the existing WebView debug harness on an approved simulator/device target and
capture a redacted `host_runtime_evidence_manifest.json`. Keep cookie/login disabled
unless a separate approval packet is present.
