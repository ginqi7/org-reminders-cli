# reminders-cli

A simple CLI to sync OS X Reminders with Emacs org mode.

Inspired by [keith/reminders-cli](https://github.com/keith/reminders-cli), this project was forked into [ginqi7/reminders-cli](https://github.com/ginqi7/reminders-cli) to meet specific requirements.

## Usage:

## Installation:

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
$ cp .build/apple/Products/Release/org-reminder /usr/local/bin/org-reminders
```
