# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
# Build release (multi-arch: arm64 + x86_64)
make build-release

# Package for release (creates tarball with completion script)
make package

# Clean build artifacts
make clean

# Run with arguments
.build/apple/Products/Release/org-reminders sync <file.org> -t once
.build/apple/Products/Release/org-reminders update-hash <file.org>
```

## Architecture Overview

This is a Swift CLI tool that syncs macOS Reminders with Emacs org-mode files, designed to work with the [org-reminders](https://github.com/ginqi7/org-reminders) Emacs package.

### Module Structure

```
Sources/
├── orgReminders/          # Main executable target
│   ├── CLI.swift          # ArgumentParser command definitions (sync, update-hash, websocket-bridge)
│   ├── Synchronization.swift  # Core sync logic between Reminders and org-mode
│   ├── OrgRemindersBridge.swift  # WebSocket bridge for Emacs communication
│   ├── ModelConverter.swift # Converts between Reminders and org-mode models
│   └── SyncLogger.swift   # Logs sync actions for Emacs consumption
├── CommonLibrary/         # Shared models
│   ├── CommonReminder.swift
│   ├── CommonList.swift
│   ├── CommonDate.swift
│   └── CommonUtils.swift
├── OrgLibrary/            # Org-mode parsing using TreeSitter
│   ├── OrgSource.swift    # Parses org files, extracts headlines
│   ├── OrgHeadline.swift
│   └── OrgDate.swift
└── SQLiteLibrary/         # SQLite utilities (optional storage)
```

### Key Dependencies

- **swift-argument-parser** - CLI framework
- **SwiftTreeSitter + tree-sitter-org** - Org-mode file parsing
- **reminders-cli** - macOS Reminders API wrapper
- **websocket-bridge-swift** - Emacs WebSocket communication
- **SQLite.swift** - SQLite bindings

### Sync Flow

1. **Fetch**: Read reminders from macOS EventKit and org headlines from file
2. **Compare**: Use SHA256 hashes and last-modified timestamps to detect changes
3. **Sync**: Bidirectional sync - newer changes win based on `lastModified` comparison
4. **Log**: Actions sent to Emacs via WebSocket or JSON for org-mode file updates

### Sync Types

- `all` - Flush all reminders to org file (initial setup)
- `once` - One-time bidirectional sync
- `auto` - Continuous sync with file system monitoring and EventKit change notifications

### Key Concepts

- **H1/H2 Headlines**: H1 sections represent lists, H2 headlines represent individual reminders
- **Hash tracking**: Each org headline stores a computed hash; changes trigger sync
- **Frequency**: Auto sync saves after N file changes (controlled by `org-reminders-sync-frequency`)
- **Display options**: Filter reminders by completion status (all/incompleted/completed)
