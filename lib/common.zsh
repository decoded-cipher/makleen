# makleen: categories, the item table and shared helpers. Sourced by the makleen entry script.

ALL_CATEGORIES=(leftovers caches projects extras)
typeset -A CATEGORY_NAME CATEGORY_HINT
CATEGORY_NAME=(
  leftovers "Leftovers from uninstalled apps"
  caches    "Tool caches"
  projects  "Build folders in idle projects"
  extras    "Optional extras"
)
CATEGORY_HINT=(
  leftovers "moved to quarantine, restorable"
  caches    "deleted, rebuild themselves"
  projects  "deleted, reinstall/rebuild to restore"
  extras    "deleted, large optional items"
)

if [[ -t 1 ]]; then
  BOLD=$'\e[1m' DIM=$'\e[2m' GREEN=$'\e[32m' YELLOW=$'\e[33m' RESET=$'\e[0m'
else
  BOLD= DIM= GREEN= YELLOW= RESET=
fi
TILDE="~"  # replacement text for showing $HOME as ~

# ---- reclaimable items, stored column-wise ----
#   kind:  rm (delete paths) | quarantine (move paths) | cmd (run shell code)
#   flag:  "" (selected by default) | review (owner unconfirmed) | optional (extra not in EXTRAS)
#   guard: process pattern; the item can't be selected while a matching process runs
typeset -a I_CAT I_LABEL I_KB I_KIND I_TARGET I_NOTE I_FLAG I_GUARD I_SIZE
typeset -a PICK LOCK ROWS SKIPPED UNUSED_APPS
ACTIVE_KB=0

add_item() {  # category label kb kind target [note] [flag] [guard]
  I_CAT+=("$1") I_LABEL+=("$2") I_KB+=("$3") I_KIND+=("$4") I_TARGET+=("$5")
  I_NOTE+=("${6:-}") I_FLAG+=("${7:-}") I_GUARD+=("${8:-}")
}

# ---- helpers ----
say()  { print -r -- "$@" }
warn() { print -ru2 -- "makleen: $*" }
die()  { warn "$@"; exit 1 }
progress()      { [[ -t 2 ]] && print -nru2 -- $'\r\e[K'"  ${DIM}$*${RESET}" }
progress_done() { [[ -t 2 ]] && print -nu2 -- $'\r\e[K' }
has()     { (( $+commands[$1] )) }
running() { local procs=$(ps -axo command=); [[ $procs == *"$1"* ]] }  # pgrep -f misses full app paths
has_fda() { ls $HOME/Library/Mail >/dev/null 2>&1 }  # Full Disk Access for this terminal
norm()    { REPLY=${(L)1}; REPLY=${REPLY//[^a-z0-9]/} }
kb_of()   { (( $# )) || { print 0; return }; du -skx -- "$@" 2>/dev/null | awk '{ s += $1 } END { print s + 0 }' }
human() {
  local k=${1:-0}
  if (( k >= 1048576 )); then printf '%.1f GB' $(( k / 1048576.0 ))
  elif (( k >= 1024 )); then printf '%.0f MB' $(( k / 1024.0 ))
  else printf '%d KB' $k
  fi
}
to_kb() {  # "4.091GB", "686.8MB", "8.1G" -> KB
  awk -v s=$1 'BEGIN { n = s + 0; u = toupper(s); gsub(/[^A-Z]/, "", u); u = substr(u, 1, 1)
    m = u == "T" ? 1073741824 : u == "G" ? 1048576 : u == "M" ? 1024 : u == "K" ? 1 : 0.001; printf "%d", n * m }'
}
free_kb() { df -k $HOME | awk 'NR == 2 { print $4 }' }
skip()    { SKIPPED+=("$1: $2") }
fit() {  # text width -> REPLY, shortened with … to fit
  local s=$1 w=$2
  (( w < 1 )) && { REPLY=; return }
  (( ${#s} > w )) && s="${s[1,w-1]}…"
  REPLY=$s
}
term_width() { local w=$(tput cols 2>/dev/null); (( w >= 60 )) || w=100; (( w > 140 )) && w=140; print $w }

disk_bar() {  # width -> REPLY
  local -a df=($(df -k $HOME | awk 'NR == 2 { print $3, $4 }'))
  local used=$df[1] free=$df[2] fill e=
  fill=$(( used * $1 / (used + free) ))
  REPLY="${(l:fill::█:)e}${(l:$1 - fill::░:)e}  $(human $used) used · $(human $free) free"
}

DOCKER_STATE=
docker_up() {
  [[ -z $DOCKER_STATE ]] && { has docker && docker info >/dev/null 2>&1 && DOCKER_STATE=up || DOCKER_STATE=down }
  [[ $DOCKER_STATE == up ]]
}

# The path, or a folder above it, matches one of the globs, ignoring case.
path_matches() {  # path glob...
  local p=${(L)1} pat
  shift
  for pat in "$@"; do
    pat=${(L)${${pat/#\~/$HOME}%%/##}}
    [[ $p == (|*/)${~pat}(|/*) || $p/ == ${~pat} ]] && return 0
  done
  return 1
}
untouchable() { path_matches $1 $NEVER_TOUCH }

# Run the catalog's entries for one pass; each entry type only acts in its own pass.
load_catalog() {  # pass
  local CATALOG_PASS=$1
  source $CATALOG_FILE
  [[ -r $USER_CATALOG ]] && source $USER_CATALOG
}

# Folders the catalog covers, so the leftovers scan doesn't report them a second time.
# Paths that need a command to work out ('$(…)') are left out rather than run here.
typeset -A CLAIMED
claim_paths() {
  local p
  for p in "$@"; do [[ $p == *'$'* ]] || CLAIMED[${p/#\~/$HOME}]=1; done
}
load_claims() {
  [[ -n ${CLAIMED[_done]} ]] && return
  CLAIMED[_done]=1
  load_catalog claims
}

# Refuse anything protected or not at least two levels below $HOME.
safe_path() { [[ ${1:a} == $HOME/?*/?* ]] && ! untouchable $1 }

# ---- run logs: every run that changes something writes $LOG_DIR/<date>_<time>_<kind>.log ----
LOG_FILE=
log_open() {  # kind
  mkdir -p $LOG_DIR || die "can't create the log folder $LOG_DIR"
  local stamp=$(strftime %Y-%m-%d_%H-%M-%S $EPOCHSECONDS) n=1
  LOG_FILE=$LOG_DIR/${stamp}_$1.log
  while [[ -e $LOG_FILE ]]; do LOG_FILE=$LOG_DIR/${stamp}_$1-$(( ++n )).log; done
  log "makleen $VERSION · $1 · $(strftime '%Y-%m-%d %H:%M:%S' $EPOCHSECONDS)"
  log "free space: $(human $(free_kb))"
  log ""
}
log() { [[ -n $LOG_FILE ]] && print -r -- "$*" >> $LOG_FILE }
log_entry() {  # result kb label [detail...]
  local result=$1 kb=$2 label=$3 line
  shift 3
  log "$(strftime %H:%M:%S $EPOCHSECONDS)  ${(r:8:)result}${(l:9:)$(human $kb)}  $label"
  for line in "$@"; do log "                             $line"; done
}

confirm() {
  (( ASSUME_YES )) && return 0
  [[ -t 0 ]] || die "not running in a terminal; re-run with --yes to proceed"
  read -q "?$1 [y/N] "; local answer=$?
  print
  return $answer
}
