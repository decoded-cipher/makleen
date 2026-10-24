# makkili config: copy to ~/.config/makkili/config.zsh and edit.
# Plain zsh, sourced by the script.

# Projects with no commit, checkout or build in this many days are "idle".
INACTIVE_DAYS=60

# Where to look for projects. Leave empty to auto-detect: any folder in ~ with several git repos
# (Desktop, Documents and Downloads are skipped unless listed here).
PROJECT_ROOTS=()

# Projects whose artifacts are never touched (globs against the project path).
PROTECT=(
  # '*/Professional/elabel_mobile'
)

# Optional extras preselected in the checklist (the rest are listed but unticked).
# Run `makkili scan extras` to see what each one would free.
#   ios-simulators     simulator devices + downloaded iOS runtimes
#   chrome-ai-model    Chrome's on-device AI model (and the policy that stops re-downloading it)
#   claude-desktop-vm  Claude desktop VM bundles (blocked while NEVER_TOUCH has *claude*)
#   android-emulators  AVDs in ~/.android/avd
#   ollama-models      every pulled Ollama model
#   old-node-versions  nvm versions other than the default and the ones pinned by .nvmrc
#   docker-unused      stopped containers + images no container uses
EXTRAS=()

# ~/Library entry names never reported as leftovers (globs).
LEFTOVER_IGNORE=()

# Paths matching these (lowercase globs) are never reported, moved or deleted.
# Defaults protect Claude / Claude Code data; add with +=, e.g. NEVER_TOUCH+=("*mkcert*").
# NEVER_TOUCH+=()

# Apps not opened in this many days are listed (report only).
UNUSED_APP_DAYS=90

# `makkili purge` without --all deletes quarantine batches older than this.
QUARANTINE_DAYS=14

# Where run logs go, one file per run named by date and time (default: logs/ next to the script).
# LOG_DIR=~/Documents/makkili-logs
