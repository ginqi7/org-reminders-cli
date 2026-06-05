# org-reminders-cli

A CLI tool for syncing macOS Reminders with storage backends (SQLite, JSON, or YAML), designed to work with [ginqi7/org-reminders](https://github.com/ginqi7/org-reminders).

Inspired by [keith/reminders-cli](https://github.com/keith/reminders-cli), this project was forked into [ginqi7/reminders-cli](https://github.com/ginqi7/reminders-cli) to meet specific requirements.

## Usage

### One-time sync

Sync macOS Reminders to storage. Format is auto-detected from file extension:
- `.db` or no extension → SQLite
- `.json` → JSON file
- `.yaml` or `.yml` → YAML file

```bash
# SQLite (default)
reminders-sync once ~/reminders.db

# JSON file
reminders-sync once ~/reminders.json

# YAML file
reminders-sync once ~/reminders.yaml
```

### Auto sync

Automatically sync changes as they occur:
```bash
reminders-sync auto ~/reminders.db
reminders-sync auto ~/reminders.json
reminders-sync auto ~/reminders.yaml
```

## Installation

#### With [Homebrew](http://brew.sh/)

```
$ brew install ginqi7/formulae/org-reminders-cli
```

#### From GitHub releases

Download the latest release from
[here](https://github.com/ginqi7/org-reminders-cli/releases)

```
$ tar -zxvf org-reminders.tar.gz
$ mv org-reminders /usr/local/bin
$ rm org-reminders.tar.gz
```

#### Building manually

This requires a recent Xcode installation.

```
$ cd org-reminders-cli
$ make build-release
$ cp .build/apple/Products/Release/reminders-sync /usr/local/bin/
```

## More Information
Find more development information at https://qiqijin.com/org-reminders.
