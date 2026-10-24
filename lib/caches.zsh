# makkili: tool caches. Sourced by the makkili entry script.

# ---- catalog entry types (the entries themselves are in catalog.zsh) ----

# cache LABEL PATH... [run=COMMAND] [needs=TOOL] [while=PROCESS] [note=TEXT] [off]
cache() {
  [[ $CATALOG_PASS == (caches|claims) ]] || return 0
  local label=$1 a run= needs= guard= note= flag= p
  local -a paths dirs
  shift
  for a in "$@"; do
    case $a in
      run=*)   run=${a#run=} ;;
      needs=*) needs=${a#needs=} ;;
      while=*) guard=${a#while=} ;;
      note=*)  note=${a#note=} ;;
      off)     flag=optional ;;
      *)       paths+=($a) ;;
    esac
  done
  if [[ $CATALOG_PASS == claims ]]; then
    claim_paths $paths
    return 0
  fi
  [[ -z $needs ]] || has $needs || return 0
  for p in $paths; do
    p=${(e)p}; p=${p/#\~/$HOME}  # single-quoted paths are expanded only now
    [[ -n $p && -d $p ]] && ! untouchable $p && dirs+=($p)
  done
  (( $#dirs )) || return 0
  local kb=$(kb_of $dirs)
  (( kb >= 10240 )) || return 0
  if [[ -n $run ]]; then
    add_item caches $label $kb cmd $run "${note:-via \`$run\`}" "$flag" "$guard"
  else
    add_item caches $label $kb rm "${(F)dirs}" "${note:-rebuilds automatically}" "$flag" "$guard"
  fi
}

# editor NAME SUPPORT_DIR EXTENSIONS_DIR while=PROCESS
# A VS Code-style editor: its download cache, its caches (skipped while it runs), and
# superseded extension versions. Skipped when the app isn't installed; then its folder is a leftover.
editor() {
  [[ $CATALOG_PASS == caches ]] || return 0
  local name=$1 support=${2/#\~/$HOME} ext=${3/#\~/$HOME} guard=${4#while=} d id
  local app=${guard%%.app/*}.app
  [[ -d $support && ( -d /Applications/$app || -d $HOME/Applications/$app ) ]] || return 0
  cache "$name downloaded extension packages" $support/CachedExtensionVSIXs
  cache "$name caches" $support/Cache $support/CachedData "$support/Code Cache" $support/GPUCache while=$guard
  # extensions.json doesn't list every installed extension, so instead keep the newest
  # folder of each extension id (publisher.name-1.2.3-darwin-arm64) and call older ones stale.
  local -a names=($ext/*(/:t)) stale versions
  for id in ${(u)names%%-[0-9]*}; do
    versions=($ext/$id-[0-9]*(/nOn))
    (( $#versions > 1 )) || continue
    for d in $versions[2,-1]; do untouchable $d || stale+=($d); done
  done
  (( $#stale )) && add_item caches "$name old extension versions" $(kb_of $stale) rm "${(F)stale}" \
    "${#stale} superseded version folder(s)" "" $guard
}

collect_caches() {
  progress "Measuring tool caches…"
  load_catalog caches
  collect_jetbrains_caches
  collect_app_caches
  collect_brew_cache
  collect_docker_cache
  collect_unavailable_simulators
}

# ---- caches that need more than a path ----

# Each JetBrains IDE upgrade leaves the previous version's caches and logs behind
# (IntelliJIdea2024.3 next to IntelliJIdea2025.2); keep the newest version of each IDE.
collect_jetbrains_caches() {
  index_installed
  (( ${${(k)APP_IDS}[(I)com.jetbrains.*]} )) || return  # no JetBrains IDE installed: it's a leftover
  local base d product
  local -a stale versions products
  for base in $HOME/Library/Caches/JetBrains $HOME/Library/Logs/JetBrains; do
    products=()
    for d in $base/*(/); do
      [[ ${d:t} =~ '^(.*[^0-9.])[0-9]{4}\.[0-9]+$' ]] && products+=($match[1])
    done
    for product in ${(u)products}; do
      versions=($base/${(b)product}[0-9][0-9][0-9][0-9].<->(/nOn))
      for d in $versions[2,-1]; do untouchable $d || stale+=($d); done
    done
  done
  (( $#stale )) || return
  local kb=$(kb_of $stale)
  (( kb >= 10240 )) && add_item caches "JetBrains caches of old IDE versions" $kb rm "${(F)stale}" \
    "keeps the newest version of each IDE"
}

# Caches of installed apps in ~/Library/Caches/<bundle id>. Apps rebuild them, and each one can't
# be selected while its app runs. Caches of apps that are gone are reported as leftovers instead.
collect_app_caches() {
  index_installed
  load_claims
  local d id app name kb
  for d in $HOME/Library/Caches/*(/); do
    id=${(L)d:t}
    [[ $id == com.apple.* || -n ${CLAIMED[$d]} ]] && continue
    app=${APP_PATH_BY_ID[$id]}
    [[ -n $app ]] && ! untouchable $d || continue
    kb=$(kb_of $d)
    (( kb >= 51200 )) || continue  # 50 MB: smaller app caches aren't worth a line
    name=${app:t:r}
    add_item caches "$name cache" $kb rm $d "$name rebuilds it" "" "$app/Contents/MacOS"
  done
}

# ---- caches whose size only the tool itself can tell ----

collect_brew_cache() {
  has brew || return
  local line=$(HOMEBREW_NO_AUTO_UPDATE=1 brew cleanup -n --prune=all 2>/dev/null | grep -o 'free approximately [0-9.]*[KMGT]B')
  [[ -n $line ]] || return
  local kb=$(to_kb ${line##* })
  (( kb >= 10240 )) && add_item caches "Homebrew old versions + downloads" $kb cmd "brew cleanup --prune=all" "via \`brew cleanup --prune=all\`"
}

collect_docker_cache() {
  has docker || return
  docker_up || { skip caches "Docker isn't running, so its build cache wasn't measured"; return }
  local line=$(docker system df --format '{{.Type}}|{{.Reclaimable}}' 2>/dev/null | grep '^Build Cache|')
  local kb=$(to_kb ${${line#*|}%% *})
  (( kb >= 10240 )) && add_item caches "Docker build cache" $kb cmd "docker builder prune -af" "via \`docker builder prune -af\`"
}

collect_unavailable_simulators() {
  xcrun --find simctl >/dev/null 2>&1 || return
  local n=$(xcrun simctl list devices unavailable 2>/dev/null | grep -c '(unavailable')
  (( n )) && add_item caches "Unavailable iOS simulators ($n)" 0 cmd "xcrun simctl delete unavailable" "simulators whose runtime is gone"
}
