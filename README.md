# makleen

Find what is eating disk space on a developer's Mac, pick what to clean, and reclaim it safely.

makleen scans your Mac for space it can reclaim: data left behind by apps you uninstalled, tool caches,
build folders in projects you haven't touched in a while, and a few large optional items. It shows
everything in a checklist, you tick what should go, and it cleans only that.

It is about 65 KB of zsh with nothing to install or compile, so you can read every line before it runs.

```
 makleen  ██████████████░░░░░░  316.9 GB used · 124.8 GB free
 Selected 48.2 GB of 70.6 GB found

  [~] Tool caches  deleted, rebuild themselves                    19.7 GB of 24.3 GB
    [x]    4.1 GB  Docker build cache
    [ ]    3.6 GB  npm cache
    [-]    993 MB  VS Code caches                                             in use
  [~] Optional extras  deleted, large optional items              28.5 GB of 46.3 GB
❯   [x]   20.5 GB  iOS simulators + 2 runtime(s)
    [ ]    8.1 GB  Android emulators: Medium_Phone, inovus_test             optional
────────────────────────────────────────────────────────────────────────────────────
 Xcode re-downloads runtimes on demand (Settings → Components) · id: ios-simulators
 runs: xcrun simctl shutdown all; xcrun simctl delete all; …
 ↑↓ move · space select · a section · enter continue · q quit
```

## Contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Use it from an AI agent](#use-it-from-an-ai-agent)
- [What it finds](#what-it-finds)
- [Safety](#safety)
- [The checklist](#the-checklist)
- [Commands and options](#commands-and-options)
- [Quarantine](#quarantine)
- [Logs](#logs)
- [Weekly report](#weekly-report)
- [Configuration](#configuration)
- [Compared with other cleaners](#compared-with-other-cleaners)
- [Limitations](#limitations)
- [Project layout](#project-layout)
- [Uninstall](#uninstall)

## Requirements

- macOS. makleen relies on macOS tools such as `lsregister`, `plutil`, `codesign`, `mdls` and `launchctl`.
  It has been tested on macOS 15 (Sequoia) on Apple Silicon.
- zsh, which macOS ships as `/bin/zsh`. Nothing else needs installing.
- The tools whose caches it cleans are optional; anything not installed is skipped.

## Quick start

```sh
brew install decoded-cipher/tap/makleen
makleen --dry-run     # scan, pick items, see the plan; nothing changes
makleen               # scan, pick items, confirm, clean
makleen scan          # just the report
```

A full scan takes about a minute.

Or run it from a clone. To run it from anywhere, link it into a folder on your `PATH`, and keep the repo
where it is: makleen follows the link to find its `lib/` folder.

```sh
git clone https://github.com/decoded-cipher/makleen && cd makleen
ln -s "$PWD/makleen" ~/.local/bin/makleen
```

## Use it from an AI agent

makleen ships an [Agent Skill](skills/makleen/SKILL.md), so you can ask Claude Code, Codex or another agent
that reads `SKILL.md` skills to free up space. The agent scans, explains what it found, investigates the
*check first* items, and cleans only what you approve after showing you the dry-run plan.

Link the skill into your agent's skills folder. With Homebrew it's in `$(brew --prefix)/share/makleen`:

```sh
ln -s "$(brew --prefix)/share/makleen/skills/makleen" ~/.claude/skills/makleen    # Claude Code
ln -s "$(brew --prefix)/share/makleen/skills/makleen" ~/.agents/skills/makleen    # Codex, and other agents that read ~/.agents/skills
```

From a clone, link `"$PWD/skills/makleen"` instead. Keep it a link rather than a copy: when makleen isn't
on your `PATH`, the skill finds it through the link.

The skill drives two options that are also useful in your own scripts: `makleen scan --json` lists every
item with an ID, and `makleen clean --id ID,...` picks exactly those items.

## What it finds

Findings are grouped into four sections. Each section is cleaned differently.

| Section | Cleaning does | Selected by default |
|---|---|---|
| Leftovers from uninstalled apps | moves them to the [quarantine](#quarantine), so you can restore them | items whose app is confirmed gone |
| Tool caches | deletes them; they rebuild on their own | all |
| Build folders in idle projects | deletes them; reinstall or rebuild to get them back | all |
| Optional extras | deletes them | only the ones listed in `EXTRAS` |

### Leftovers from uninstalled apps

When you drag an app to the Trash, its data in `~/Library` stays behind. makleen looks in
`Application Support` (including its `Caches` folder), `Caches`, `Containers`, `Group Containers` and `Logs`. For apps
that macOS remembers as once installed, it also looks in `Preferences`, `Saved Application State`,
`HTTPStorages`, `WebKit`, `Application Scripts` and `Cookies`.

A folder is reported only when no installed app owns it. makleen compares each folder with the bundle ID,
name, executable and vendor of every installed app, matches group containers by the app's team ID, and
treats folders named after an installed command-line tool as that tool's data. Apple's own folders are
always skipped: a folder is Apple's when macOS ships a framework, app, daemon or launch job of that name,
or when it is on a short built-in list. Folders the catalog covers are reported as caches instead.
Folders are grouped per app, and apps with less than 1 MB of leftovers are folded into one line.

macOS won't let other apps move folders in `~/Library/Containers` unless your terminal has Full Disk
Access. Without it, leftovers there are listed separately as *(app container)* and can't be selected.

Each leftover is either confirmed or marked **check first**:

- **Confirmed**: macOS remembers the app, and none of the places it was installed still exists. Folders
  with a browser or Electron profile inside, and bundle IDs that no installed app uses, also count.
- **Check first**: the owner is unclear, for example a folder that may belong to a command-line tool, or
  one from a vendor that still has another app installed. These start unticked.

### Tool caches

The caches makleen knows are listed in [catalog.zsh](catalog.zsh), one line each. Only the ones that exist
on your Mac, and whose tool is installed where that matters, show up.

| Area | Caches |
|---|---|
| JavaScript | npm, npx, Bun, pnpm (unused packages only), Yarn, Deno, Puppeteer, Playwright, Cypress, Electron, node-gyp, Prisma, Expo, Wrangler logs |
| Go, Rust | Go module and build caches, Cargo downloaded crates |
| Python | uv, pip, Poetry, Conda packages |
| JVM | Gradle caches and wrapper distributions, Maven repository (starts unticked: it also holds what you `mvn install`ed) |
| Ruby, PHP, Dart | RubyGems, Bundler, Composer, Dart and Flutter packages |
| Apple and mobile | CocoaPods, Xcode DerivedData and device support files, simulator caches, Swift Package Manager, Android build caches, unavailable simulators |
| Browsers | Chrome, Brave, Edge and Firefox caches only; history, logins and settings stay |
| Editors | VS Code, Cursor, VSCodium and Windsurf caches and superseded extension versions; JetBrains caches of old IDE versions, keeping the newest of each IDE |
| Apps | caches of installed apps in `~/Library/Caches` over 50 MB |
| Others | Homebrew old versions and downloads, Docker build cache, Arduino download staging |

Where a tool has its own clean command (`npm cache clean`, `go clean -modcache`, `brew cleanup`,
`docker builder prune`, …), makleen uses it; other caches are deleted. Items that belong to an app,
such as browser, editor and app caches, can't be selected while that app runs. Cache folders under
10 MB are not listed.

**Add your own.** Put lines in the same format in `~/.config/makleen/catalog.zsh`; they're loaded after
the built-in catalog:

```zsh
cache "My tool's cache"  ~/.mytool/cache
cache "Other tool cache" ~/Library/Caches/othertool  run="othertool cache clear" needs=othertool
extra big-models "Downloaded models" ~/ml/models  note="downloaded again when needed"
```

`run=` cleans with the tool's own command instead of deleting, `needs=` skips the line when that command
isn't installed, `while=` locks the item while a matching process runs, `note=` explains it, and `off` makes
it start unticked. An `extra` starts unticked unless its ID is listed in `EXTRAS`. A path in single quotes
is expanded only when the line is used: `'$(go env GOMODCACHE)'` runs `go` only if it's installed.
Folders must be at least two levels inside your home folder (`~/.tool/cache`, not `~/.tool`), and must
not match `NEVER_TOUCH`; others are never offered.

### Build folders in idle projects

makleen looks for projects in `PROJECT_ROOTS`. When that is empty, it uses every folder in your home
folder that contains at least two git repositories within three levels. Desktop, Documents and Downloads
are skipped, because reading them makes macOS ask for permission; list them in `PROJECT_ROOTS` if your
projects live there.

A folder counts as a build artifact only when the file that produces it sits next to it:

| Folder | Must sit next to | Restore with |
|---|---|---|
| `node_modules` | `package.json` | `npm install`, or `pnpm`/`yarn`/`bun install`, detected from the lock file |
| `.next` `.nuxt` `.svelte-kit` `.turbo` `.parcel-cache` `.angular` `.expo` | `package.json` | the next build or dev run |
| `.venv` `venv` `env` | must contain `pyvenv.cfg` | `uv sync`, `poetry install`, or recreate it and `pip install` |
| `Pods` | `Podfile` | `pod install` |
| `build` | `build.gradle(.kts)`, `pubspec.yaml`, or an `ios/` folder with a `Podfile` | the next build |
| `.cxx` `.gradle` | a Gradle build or settings file | the next build |
| `target` | `Cargo.toml` or `pom.xml` | `cargo build` or `mvn package` |
| `.dart_tool` | `pubspec.yaml` | `flutter pub get` |
| `.terraform` | a `.tf` file | `terraform init` |

A folder containing any file tracked by git is never touched, whatever its name.

A project is idle when the newest of these is older than `INACTIVE_DAYS` (60 by default):

- its last commit
- the last change to git's HEAD, which moves on commit, checkout, pull and rebase
- the build folder's own modification time, which moves on install or build
- for folders without git history, the newest file within three levels

Each idle project is one line in the checklist, covering all of its build folders.

### Optional extras

| ID | What it removes | Notes |
|---|---|---|
| `ios-simulators` | every simulator device and downloaded iOS runtime | Xcode downloads runtimes again when needed (Settings → Components) |
| `chrome-ai-model` | Chrome's on-device AI model (`OptGuideOnDeviceModel`) | also sets the Chrome policy `GenAILocalFoundationalModelSettings` to 1 so it isn't downloaded again |
| `android-emulators` | the emulators in `~/.android/avd` | recreate them in Android Studio → Device Manager |
| `ollama-models` | every pulled Ollama model, with `ollama rm` | Ollama must be running; `ollama pull` brings a model back |
| `old-node-versions` | Node versions from nvm, fnm, Volta, asdf or mise that nothing needs | keeps each manager's default and newest version, the `node` on your `PATH`, and versions pinned by `.nvmrc`, `.node-version` or `.tool-versions` in your projects or home folder; an exact pin keeps that version, a major-only pin the newest of that major |
| `docker-unused` | stopped containers and images no container uses | data in a stopped container that isn't in a volume is lost |
| `ml-models` | Hugging Face and PyTorch model downloads (`~/.cache/huggingface/hub`, `~/.cache/torch`) | downloaded again the next time a model is used |
| `xcode-archives` | Xcode archives of builds you made | you need them to symbolicate crash reports from builds you shipped |
| `claude-desktop-vm` | Claude desktop's VM bundles, while Claude.app is installed | downloaded again if you use its agent features |

Extras listed in `EXTRAS` start ticked; the others are listed unticked. The ones that are plain folders
(`ml-models`, `xcode-archives`) are catalog lines, so you can add more of your own the same way.

### Apps you don't use

The full report also lists apps in `/Applications` not opened in `UNUSED_APP_DAYS` (90 by default), with
their size. makleen never uninstalls apps.

## Safety

What makleen never does:

- **Use `sudo`.** Everything it deletes or moves itself has to be at least two folders deep inside your
  home folder, and macOS protects its own system files anyway.
- **Touch protected paths.** Anything matching a `NEVER_TOUCH` pattern you set is skipped by every scan
  and refused by the delete and move steps. Nothing is protected this way by default; a pattern matches
  anywhere in the path, so keep it specific, for example `'*/.claude/*'`.
- **Look in your personal data.** Photos, Mail, Messages and the keychain are never scanned or cleaned.
  Desktop, Documents and Downloads are only searched for projects if you add them to `PROJECT_ROOTS`.
- **Delete without asking.** Nothing happens until you confirm the plan, unless you pass `--yes`.
- **Clean anything in use.** Items that belong to a running app, such as a browser, an editor, the iOS
  Simulator or an Android emulator, can't be selected.

What cleaning costs:

- Caches and build folders come back, but the next install or build re-downloads and takes longer.
- Projects without a lock file can get newer package versions on reinstall, which occasionally breaks an
  old project.
- iOS simulator runtimes are several GB each to download again.
- Some MCP servers start through `npx`. If one is running while the npx cache is cleared, restart it.

Run `makleen --dry-run` first to see exactly what would happen.

## The checklist

| Key | Action |
|---|---|
| `↑` `↓` or `j` `k` | move |
| `PgUp` `PgDn` | move a page |
| `g` `G` or `Home` `End` | jump to the top or bottom |
| `space` | tick or untick the item; on a section header, the whole section |
| `a` | tick or untick the whole section the cursor is in |
| `enter` | continue to the plan and confirmation |
| `q` or `Esc` | quit; nothing changes |

| Mark | Meaning |
|---|---|
| `[x]` `[ ]` | selected, not selected |
| `[~]` | part of the section is selected |
| `[-]` | can't be selected: its app is running |
| `check first` | the owner of this leftover is unclear |
| `optional` | an extra that isn't listed in `EXTRAS` |

The panel at the bottom explains the highlighted item and shows its first path or the command it runs.
The total at the top updates as you tick items.

## Commands and options

```
makleen                          scan, then pick what to clean from the checklist
makleen scan [CATEGORY...]       print a report; nothing changes
makleen scan --json              the same scan as JSON, every item with its ID
makleen clean [CATEGORY...]      the checklist for some categories only
makleen quarantine               list quarantined batches
makleen restore BATCH            move a batch back where it came from
makleen purge                    permanently delete batches older than QUARANTINE_DAYS
makleen schedule install|remove  set up or remove the weekly report
makleen help | --version
```

Categories are `leftovers`, `caches`, `projects` and `extras`. Plain `makleen` without a terminal, for
example in a pipe, prints the report instead of opening the checklist, and `--dry-run` without a terminal
shows the plan for the preselected items.

| Option | Effect |
|---|---|
| `--dry-run` | show the plan and stop |
| `--only TEXT` | preselect only items whose name or path contains `TEXT`, including *check first* and optional ones |
| `--id ID,...` | clean only the items with these IDs, from `scan --json`, without the checklist; scans only their categories |
| `--json` | `scan`: print every item as JSON |
| `--yes` | skip the checklist and the confirmation, and clean the preselected items |
| `--days N` | count projects as idle after `N` days |
| `--all` | `scan`: list every item instead of the largest ten per section; `purge`: delete every batch |
| `--older-than N` | `purge`: delete batches older than `N` days |

Clean one thing without the checklist:

```sh
makleen clean leftovers --only cursor --dry-run   # check what matches
makleen clean leftovers --only cursor --yes
makleen clean --id caches/npm-cache,extras/ios-simulators --yes
```

An item's ID is its category and a slug of its name, such as `caches/npm-cache`; extras use their own ID,
such as `extras/ios-simulators`.

## Quarantine

Leftovers are moved, not deleted, to `~/.makleen/quarantine/<date>-<time>/`, keeping their original
paths and a `MANIFEST` of what came from where. **They still use disk space until you purge them.**

```sh
makleen quarantine                 # list batches with size and contents
makleen restore 20261025-032640    # put a batch back
makleen purge                      # delete batches older than QUARANTINE_DAYS (14 by default)
makleen purge --all                # delete every batch now
```

Restore never overwrites: if something exists at the original path again, that item stays in quarantine.

## Logs

Every run that changes something writes one log file, named by when it started. Logs go to `logs/` in
the repo when you run makleen from a clone, and to `~/.makleen/logs/` otherwise, as with Homebrew:

```
logs/2026-10-25_03-26-40_clean.log
logs/2026-10-25_03-31-02_restore.log
logs/2026-10-25_03-40-15_purge.log
logs/2026-11-01_10-00-00_report.log
```

Each item gets a line with its result (`done`, `partial`, `failed` or `skipped`), followed by the paths it
deleted or quarantined, or the command it ran with that command's output and exit status. Every log
starts with your free space; clean and purge logs also end with it.

```
03:26:45  done       4.1 GB  [caches] Docker build cache
                             ran: docker builder prune -af
                             │ Total reclaimed space: 4.091GB
03:27:41  done       9.2 GB  [projects] work/mobile-app
                             deleted ~/Developer/work/mobile-app/node_modules
```

`scan` and `--dry-run` change nothing and write no log. In a clone the `logs/` folder is git-ignored because
logs contain your own paths. Set `LOG_DIR` to keep them elsewhere.

## Weekly report

```sh
makleen schedule install   # Sundays at 10:00
makleen schedule remove
```

This adds a launchd agent (`dev.makleen.weekly`) that runs a full scan, writes the report to
`<date>_<time>_report.log` in the [log folder](#logs), and shows a notification with how much can be
reclaimed. It never deletes anything. The agent records the script's location and your `PATH` when you
install it, so run `schedule install` again after moving the repo. Homebrew upgrades don't need that.

## Configuration

Copy [config.example.zsh](config.example.zsh) to `~/.config/makleen/config.zsh` and edit it. It is plain
zsh.

| Setting | Default | Meaning |
|---|---|---|
| `INACTIVE_DAYS` | `60` | days without use before a project counts as idle |
| `PROJECT_ROOTS` | auto-detected | folders to search for projects |
| `PROTECT` | none | globs of projects, or folders of projects, whose build folders are never touched |
| `EXTRAS` | none | extras that start ticked, by ID |
| `LEFTOVER_IGNORE` | none | globs of `~/Library` entry names never reported as leftovers |
| `NEVER_TOUCH` | none | globs of paths never reported, moved or deleted, along with everything inside them; a pattern matches anywhere in the path |
| `UNUSED_APP_DAYS` | `90` | days without opening before an app is listed in the report |
| `QUARANTINE_DAYS` | `14` | age at which `makleen purge` deletes a batch |
| `LOG_DIR` | `logs/` in a clone, else `~/.makleen/logs` | where run logs go |

Patterns ignore case, and in `PROTECT` and `NEVER_TOUCH` a leading `~` is your home folder. A bare name
matches a folder of that name anywhere: `NEVER_TOUCH=(mkcert)` protects every `mkcert` folder and what's in it.

Your own caches and extras go in `~/.config/makleen/catalog.zsh`; see [Tool caches](#tool-caches).

Environment variables: `MAKLEEN_CONFIG` and `MAKLEEN_CATALOG` point at a different config or catalog
file, and `MAKLEEN_HOME` moves the state folder (default `~/.makleen`, which holds the quarantine).

## Compared with other cleaners

Sizes are download sizes; sizes and prices were checked in October 2026.

| Tool | What it is | Size | Price | Focus |
|---|---|---|---|---|
| makleen | zsh script | 65 KB | free, MIT | dev caches, idle projects' build folders, leftovers of deleted apps |
| [CleanMyMac](https://cleanmymac.com) | app, plus a CLI preview | 346 MB | about $40 a year | general cleanup, uninstaller, malware scan; the CLI adds dev caches and old build folders |
| [Mole](https://github.com/tw93/Mole) | CLI, shell and Go | about 8 MB | free, GPL-3.0 | caches, build folders, uninstaller, disk map, system tweaks |
| [Pearcleaner](https://github.com/alienator88/Pearcleaner) | app | 11 MB | free, source-available | uninstaller with an orphaned-file search |
| [AppCleaner](https://freemacsoft.net/appcleaner/) | app | 3–4 MB | free | uninstaller |
| [DaisyDisk](https://daisydiskapp.com) | app | 3 MB | $9.99 | map of what uses space; you decide what to delete |
| [DevCleaner for Xcode](https://apps.apple.com/app/id1388020431) | app with a CLI | 6 MB | free | Xcode's caches only |
| [npkill](https://github.com/voidcosmos/npkill) | Node CLI | 135 KB, plus Node | free, MIT | `node_modules` only |
| [kondo](https://github.com/tbillington/kondo) | Rust CLI | 1 MB | free, MIT | build folders in 20+ project types |

Where makleen differs:

- **Leftovers can be undone.** They go to a [quarantine](#quarantine) you can restore from. Mole's `clean` and
  `purge` delete permanently.
- **Idle means unused for a while.** A project counts as idle after 60 days without a commit, checkout or
  build. CleanMyMac's and Mole's build-folder cleaners preselect anything without activity in the last 7 days.
- **Nothing to trust blindly.** There is no binary and no installer, only shell code, and every command it
  runs is shown in the checklist and the log.

What it doesn't do: uninstall apps, map disk usage, empty the Trash, clean anything that needs `sudo`, or
offer a GUI. For those, use one of the tools above.

## Limitations

- Leftover detection is a judgement made from installed apps and what macOS remembers. It has only been
  tested on one Mac, which is why leftovers are quarantined rather than deleted.
- Without Full Disk Access for your terminal, Mail, Messages, Photos, Safari and the Trash can't be
  measured, and leftovers in app containers can't be moved. makleen doesn't clean those personal folders
  anyway, but the report says so. Moving app containers with Full Disk Access hasn't been tested.
- System-wide leftovers outside your home folder, such as files in `/etc` or `/Library` left by an
  uninstaller, are out of scope because makleen never uses `sudo`.
- Docker's build cache and unused images are measured only while Docker is running.
- Catalog lines for tools that weren't on the test Mac (Cargo, Maven, Conda, Composer, Dart and others)
  were checked against test folders, not real installs of those tools.

## Project layout

| File | What it holds |
|---|---|
| `makleen` | usage text, settings, config loading and the command dispatcher |
| `skills/makleen/SKILL.md` | the Agent Skill for Claude Code, Codex and other agents |
| `catalog.zsh` | the caches and simple extras makleen knows, one line each |
| `lib/common.zsh` | the item table, sizes, logging, catalog loading, and the safety checks (`NEVER_TOUCH`, `safe_path`) |
| `lib/leftovers.zsh` | detecting data of uninstalled apps |
| `lib/caches.zsh` | the `cache` and `editor` catalog entries, and caches that need more than a path: JetBrains, installed apps, Homebrew, Docker |
| `lib/projects.zsh` | idle projects and their build folders |
| `lib/extras.zsh` | optional extras |
| `lib/scan.zsh` | running the scanners and the default selection |
| `lib/report.zsh` | the `makleen scan` report and its JSON form |
| `lib/checklist.zsh` | the interactive checklist |
| `lib/clean.zsh` | cleaning what was picked |
| `lib/quarantine.zsh` | `quarantine`, `restore` and `purge` |
| `lib/schedule.zsh` | the weekly report |

To add a cache everyone should get, add a line to `catalog.zsh`. Only caches that need logic, like
keeping the newest version of something, belong in `lib/caches.zsh`.

## Uninstall

```sh
makleen schedule remove        # if you installed the weekly report
makleen purge --all            # or restore anything you still want first
rm -rf ~/.makleen ~/.config/makleen
```

Then `brew uninstall makleen`, or for a clone remove `~/.local/bin/makleen` and delete the repo folder,
including `logs/` if you don't want the history. Remove the skill links from your agents' skills folders.

## License

[MIT](LICENSE)

---

The name is *mac clean*, said quickly.
