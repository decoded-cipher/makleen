# makkili: tool caches. Sourced by the makkili entry script.

cache_dir() {  # label dir... (plain cache folders, deleted outright)
  local label=$1 d; shift
  local -a dirs
  for d in "$@"; do [[ -d $d ]] && ! untouchable $d && dirs+=($d); done
  (( $#dirs )) || return
  local kb=$(kb_of $dirs)
  (( kb >= 10240 )) && add_item caches $label $kb rm "${(F)dirs}" "rebuilds automatically" "" "${CACHE_GUARD:-}"
}

cache_tool() {  # tool label dir command (cleaned by the tool's own command)
  local tool=$1 label=$2 dir=$3 cmd=$4
  has $tool && [[ -n $dir && -d $dir ]] || return
  local kb=$(kb_of $dir)
  (( kb >= 10240 )) && add_item caches $label $kb cmd $cmd "via \`$cmd\`"
}

collect_caches() {
  progress "Measuring tool caches…"
  cache_tool npm "npm cache" $HOME/.npm/_cacache "npm cache clean --force"
  cache_dir "npx package cache" $HOME/.npm/_npx
  cache_tool bun "Bun install cache" $HOME/.bun/install/cache "bun pm cache rm"
  has pnpm && cache_tool pnpm "pnpm store, unused packages" "$(pnpm store path 2>/dev/null)" "pnpm store prune"
  has yarn && cache_tool yarn "Yarn cache" "$(yarn cache dir 2>/dev/null)" "yarn cache clean"
  has go   && cache_tool go "Go module cache" "$(go env GOMODCACHE 2>/dev/null)" "go clean -modcache"
  has go   && cache_tool go "Go build cache" "$(go env GOCACHE 2>/dev/null)" "go clean -cache"
  has uv   && cache_tool uv "uv cache" "$(uv cache dir 2>/dev/null)" "uv cache clean"
  has pip3 && cache_tool pip3 "pip cache" "$(pip3 cache dir 2>/dev/null)" "pip3 cache purge"
  cache_tool pod "CocoaPods cache" $HOME/Library/Caches/CocoaPods "pod cache clean --all"
  cache_dir "Puppeteer browser downloads" $HOME/.cache/puppeteer
  cache_dir "Gradle caches" $HOME/.gradle/caches
  cache_dir "Arduino download staging" $HOME/Library/Arduino15/staging
  cache_dir "Expo simulator/APK caches" $HOME/.expo/ios-simulator-app-cache $HOME/.expo/android-apk-cache
  cache_dir "Wrangler logs" $HOME/Library/Preferences/.wrangler/logs
  cache_dir "Xcode DerivedData" $HOME/Library/Developer/Xcode/DerivedData
  collect_vscode_caches
  collect_brew_cache
  collect_docker_cache
  collect_unavailable_simulators
}

collect_vscode_caches() {
  local support="$HOME/Library/Application Support/Code" ext=$HOME/.vscode/extensions d
  [[ -d $support ]] || return
  cache_dir "VS Code downloaded extension packages" $support/CachedExtensionVSIXs
  local CACHE_GUARD="Visual Studio Code.app/Contents/MacOS"
  cache_dir "VS Code caches" $support/Cache $support/CachedData "$support/Code Cache" $support/GPUCache
  # extensions.json doesn't list every installed extension, so instead keep the newest
  # folder of each extension id (publisher.name-1.2.3-darwin-arm64) and call older ones stale.
  local -a names=($ext/*(/:t)) stale versions
  local id
  for id in ${(u)names%%-[0-9]*}; do
    versions=($ext/$id-[0-9]*(/nOn))
    (( $#versions > 1 )) || continue
    for d in $versions[2,-1]; do untouchable $d || stale+=($d); done
  done
  (( $#stale )) && add_item caches "VS Code old extension versions" $(kb_of $stale) rm "${(F)stale}" \
    "${#stale} superseded version folder(s)" "" $CACHE_GUARD
}

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
