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
```

## Architecture Overview

This is a Swift CLI tool that syncs macOS Reminders with a storage backend (SQLite, JSON, or YAML files). The sync is bidirectional with last-write-wins conflict resolution. The storage is consumed by the [org-reminders](https://github.com/ginqi7/org-reminders) Emacs package to provide org-mode integration.

### Module Structure

```
Sources/
├── remindersSync/      # Main executable target
│   ├── main.swift      # Entry point, EventKit access check
│   ├── CLI.swift       # ArgumentParser subcommands
│   ├── Synchronization.swift  # Core sync logic
│   ├── FileStorage.swift      # JSON/YAML file storage
│   └── SyncLogger.swift       # JSON logging for sync actions
├── CommonLibrary/      # Shared models (Codable, no dependencies)
│   ├── CommonReminder.swift
│   ├── CommonList.swift
│   └── CommonDate.swift
└── SQLiteLibrary/      # SQLite persistence layer
    ├── SQLiteReminder.swift
    └── SQLiteList.swift
```

### Key Dependencies

- **swift-argument-parser** - CLI framework
- **ginqi7/reminders-cli** - macOS Reminders API (EventKit wrapper)
- **SQLite.swift** - SQLite bindings
- **Yams** - YAML encoding/decoding

### Sync Flow

1. **Fetch**: Read reminders/lists from macOS EventKit via `reminders-cli`
2. **Compare**: Use `lastModified` timestamps to detect which source is newer
3. **Sync**: Bidirectional sync - newer changes win (last-write-wins)
4. **Log**: Actions written as JSON for Emacs consumption

### CLI Commands

- `once <path>` - One-time sync to storage (auto-detects format from extension: `.db`=SQLite, `.json`=JSON, `.yaml`/`.yml`=YAML)
- `auto <path>` - Continuous sync (auto-detects format from extension)

### Key Concepts

- **Auto-detection**: Format is determined by file extension - `.json` for JSON, `.yaml`/`.yml` for YAML, `.db` or no extension for SQLite
- **Last-write-wins**: When a reminder differs between sources, the one with the newer `lastModified` timestamp wins
- **Storage backends**: SQLite (default), JSON file, or YAML file
- **Deleted reminders**: Soft-deleted in storage (marked `isDeleted = true`) rather than hard deleted
- **FileData structure**: JSON/YAML files store both `lists` and `reminders` in a single file with `FileData` struct