# Stitch UI Handoff Plan

Generated: 2026-05-15
Status: EXTERNAL_IN_PROGRESS

---

## 1. Stitch Positioning

Stitch is the **multi-platform common frontend design/prototype source** for Reader apps.

- NOT part of Reader-iOS current automated development loop
- Will produce UI specifications consumed by Reader-iOS, Reader-Android, etc.
- Reader-iOS native capability surface (S0-S12) is the foundation Stitch UI builds upon

---

## 2. Stitch Deliverables

| Category | Items |
|----------|-------|
| **IA / Navigation** | Tab structure, page hierarchy, deep links |
| **Bookshelf** | List layout, grouping, progress bar, swipe actions |
| **Book Source Management** | List, import, enable/disable, JSON export |
| **Search** | Search bar, results list, pagination, history |
| **Book Detail** | Metadata display, add-to-bookshelf, TOC entry |
| **TOC / Chapter List** | Chapter list, reverse order, scroll position |
| **Reader Page** | Content area, prev/next, settings panel, TTS control |
| **Reader Settings** | Font/size/spacing/theme/page-turn controls |
| **WebDAV / Sync** | Settings form, schedule picker, backup status |
| **Local Book Import** | File picker, import progress, metadata |
| **Design Tokens** | Colors, fonts, spacing, icons, dark mode |
| **Adaptation** | Small/large screen, portrait/landscape, iPad split view |
| **Interaction Flows** | Screen transitions, gesture specs, loading/error/empty states |

---

## 3. iOS Native Capability Surface (Already Built)

| Layer | What Stitch UI Can Call |
|-------|------------------------|
| **Navigation** | Route enum (9 cases), TabView (4 tabs) |
| **Data** | ReaderCoreServiceProvider (real/mock), BookshelfStore, ReadingProgressStore, ReaderSettingsStore |
| **Services** | SearchService, TOCService, ContentService |
| **Sync** | ProgressSyncManager, ProgressSyncAdapterProtocol |
| **WebView** | ProductionWebViewAdapter, WebViewSecurityGate |
| **Import** | FileImporter, DefaultBookSourceDecoder |

---

## 4. iOS UI Resumption Conditions

iOS UI implementation loop will resume when:

1. Stitch design freeze achieved
2. Multi-platform component spec frozen
3. iOS adaptation rules defined
4. Page transition relationships clear
5. State flows aligned with ReadingFlowCoordinator / Persistence layer
6. User explicitly authorizes iOS UI implementation loop restart

---

## 5. Not In Current Scope

- SwiftUI page implementation
- Visual refinement / pixel-perfect UI
- Design token integration
- TestFlight product RC
- App Store submission
