# Active Context - YTDx Downloader

## Current Work Focus
- Resolved the 20 FPS UI stuttering caused by whole-tree rebuilds during state notifications by implementing `context.select` on root layout widgets (`MainShell`, `Sidebar`, `AuraApp`).

## Recent Changes
- **Root Layout Rebuild Elimination**: `MainShell` and `Sidebar` now select only `currentTabIndex` and `activeDownloadCount`, preventing global rebuilds on download ticks.
- **Static Screen Hierarchy**: Fixed `IndexedStack` child allocations with `static const List<Widget>`.
- **Verification**: `flutter analyze` (0 issues), `flutter test` (100% pass), and compiled in AOT Release mode (`task-4081`).
