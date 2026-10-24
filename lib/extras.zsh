# makkili: large optional items, preselected only when named in EXTRAS. Sourced by the makkili entry script.

add_extra() {  # name label kb kind target note [guard]
  local flag=
  (( ${EXTRAS[(Ie)$1]} )) || flag=optional
  add_item extras "$2" "$3" "$4" "$5" "$6 · id: $1" "$flag" "${7:-}"
}

extra_ios_simulators() {
  xcrun --find simctl >/dev/null 2>&1 || return
  local devices=$HOME/Library/Developer/CoreSimulator/Devices kb=0 line
  local -a ids
  [[ -d $devices ]] && kb=$(kb_of $devices)
  for line in ${(f)"$(xcrun simctl runtime list -v 2>/dev/null)"}; do
    if [[ $line =~ ' - ([0-9A-F-]{36})' ]]; then ids+=($match[1])
    elif [[ $line =~ '^ +Size: ([0-9.]+[KMGT])' ]]; then (( kb += $(to_kb $match[1]) ))
    fi
  done
  (( kb >= 10240 )) || return
  local cmd="xcrun simctl shutdown all; xcrun simctl delete all"
  (( $#ids )) && cmd+="; for id in $ids; do xcrun simctl runtime delete \$id; done"
  add_extra ios-simulators "iOS simulators + ${#ids} runtime(s)" $kb cmd $cmd \
    "Xcode re-downloads runtimes on demand (Settings → Components)" "Simulator.app/Contents/MacOS"
}

extra_chrome_ai_model() {
  local d="$HOME/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel"
  [[ -d $d ]] || return
  local kb=$(kb_of $d)
  (( kb >= 10240 )) || return
  # the policy stops Chrome from downloading the model again
  add_extra chrome-ai-model "Chrome on-device AI model" $kb cmd \
    "rm -rf ${(q)d} && defaults write com.google.Chrome GenAILocalFoundationalModelSettings -int 1" \
    "also sets the Chrome policy that blocks re-downloading it" "Google Chrome.app/Contents/MacOS/Google Chrome"
}

extra_claude_vm() {
  [[ -d /Applications/Claude.app ]] || return  # app removed: the whole folder is reported under leftovers
  local s="$HOME/Library/Application Support/Claude"
  local -a dirs=($s/vm_bundles(/) $s/claude-code-vm(/))
  (( $#dirs )) || return
  add_extra claude-desktop-vm "Claude desktop VM bundles" $(kb_of $dirs) rm "${(F)dirs}" \
    "re-downloaded if you use Claude desktop's agent features" "Claude.app/Contents/MacOS"
}

extra_android_emulators() {
  local -a avds=($HOME/.android/avd/*.avd(/))
  (( $#avds )) || return
  add_extra android-emulators "Android emulators: ${(j:, :)${(@)avds:t:r}}" $(kb_of $avds) rm "${(F)avds}"$'\n'"${(F)${avds/%.avd/.ini}}" \
    "recreate in Android Studio → Device Manager" "qemu-system"
}

extra_ollama_models() {
  has ollama && [[ -d $HOME/.ollama/models ]] || return
  local kb=$(kb_of $HOME/.ollama/models)
  (( kb >= 10240 )) || return
  local models=$(ollama list 2>/dev/null | awk 'NR > 1 { printf "%s%s", sep, $1; sep = ", " }')
  add_extra ollama-models "Ollama models: ${models:-server not running}" $kb cmd \
    "ollama list | awk 'NR > 1 { print \$1 }' | xargs -n1 ollama rm" "re-pull with \`ollama pull <model>\`"
}

extra_old_node() {
  local base=$HOME/.nvm/versions/node f w v
  local -a versions=($base/v*(/n)) wanted keep drop newest
  (( $#versions > 1 )) || return
  [[ -r $HOME/.nvm/alias/default ]] && wanted+=($(<$HOME/.nvm/alias/default))
  for f in ${(f)"$(find $PROJECT_ROOTS -maxdepth 4 \( -name node_modules -o -name .git \) -prune -o \
                  \( -name .nvmrc -o -name .node-version \) -type f -print 2>/dev/null)"}; do
    wanted+=($(<$f))
  done
  for w in $wanted; do  # exact pins are kept as is; "22" keeps the newest installed 22.x
    w=${w#v}
    if [[ $w == <->.<->.<-> ]]; then [[ -d $base/v$w ]] && keep+=($base/v$w); continue; fi
    w=${w%%.*}
    [[ $w == <-> ]] || continue
    newest=($base/v$w.*(/nOn))
    (( $#newest )) && keep+=($newest[1])
  done
  [[ $commands[node] == $base/* ]] && keep+=(${commands[node]%/bin/node})
  (( $#keep )) || keep=($versions[-1])
  for v in $versions; do (( ${keep[(Ie)$v]} )) || drop+=($v); done
  (( $#drop )) || return
  add_extra old-node-versions "Old Node versions: ${(j:, :)${(@)drop:t}}" $(kb_of $drop) rm "${(F)drop}" \
    "keeps ${(j:, :)${(@u)keep:t}} (nvm default + .nvmrc/.node-version pins)"
}

extra_docker_unused() {
  docker_up || return
  local kb=0 line
  for line in ${(f)"$(docker system df --format '{{.Type}}|{{.Reclaimable}}' 2>/dev/null)"}; do
    [[ $line == (Images|Containers)\|* ]] && (( kb += $(to_kb ${${line#*|}%% *}) ))
  done
  (( kb >= 10240 )) || return
  add_extra docker-unused "Docker stopped containers + unused images" $kb cmd \
    "docker container prune -f && docker image prune -af" "stopped containers lose any data not kept in a volume"
}

collect_extras() {
  progress "Measuring optional extras…"
  (( $#PROJECT_ROOTS )) || detect_project_roots
  extra_ios_simulators
  extra_chrome_ai_model
  extra_claude_vm
  extra_android_emulators
  extra_ollama_models
  extra_old_node
  extra_docker_unused
}
