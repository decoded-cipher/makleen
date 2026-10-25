# makleen: large optional items, preselected only when named in EXTRAS. Sourced by the makleen entry script.

add_extra() {  # name label kb kind target note [guard]
  local flag=
  (( ${EXTRAS[(Ie)$1]} )) || flag=optional
  add_item extras "$2" "$3" "$4" "$5" "$6 · id: $1" "$flag" "${7:-}"
}

# Catalog entry type for extras that are plain folders:
# extra ID LABEL PATH... [while=PROCESS] [note=TEXT]
extra() {
  [[ $CATALOG_PASS == (extras|claims) ]] || return 0
  local id=$1 label=$2 a guard= note= p
  local -a paths dirs
  shift 2
  for a in "$@"; do
    case $a in
      while=*) guard=${a#while=} ;;
      note=*)  note=${a#note=} ;;
      *)       paths+=($a) ;;
    esac
  done
  if [[ $CATALOG_PASS == claims ]]; then
    claim_paths $paths
    return 0
  fi
  for p in $paths; do
    p=${(e)p}; p=${p/#\~/$HOME}
    [[ -n $p && -d $p ]] && safe_path $p && dirs+=($p)  # only folders makleen may delete
  done
  (( $#dirs )) || return 0
  local kb=$(kb_of $dirs)
  (( kb >= 10240 )) || return 0
  add_extra $id $label $kb rm "${(F)dirs}" "${note:-deleted}" $guard
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

# Node versions installed by nvm, fnm, Volta, asdf or mise. Kept: each manager's default and newest
# version, the node on PATH, and versions pinned by .nvmrc, .node-version or .tool-versions in your
# projects or home folder. An exact pin keeps that version; "22" keeps the newest 22.x of each manager.
extra_old_node() {
  local fnm_dir=${FNM_DIR:-$HOME/.local/share/fnm} volta=${VOLTA_HOME:-$HOME/.volta}
  local -a spec=(
    nvm   $HOME/.nvm/versions/node
    fnm   $fnm_dir/node-versions
    fnm   "$HOME/Library/Application Support/fnm/node-versions"
    volta $volta/tools/image/node
    asdf  ${ASDF_DATA_DIR:-$HOME/.asdf}/installs/nodejs
    mise  ${MISE_DATA_DIR:-$HOME/.local/share/mise}/installs/node
  )
  local i d f w link line
  local -a all managers wanted keep drop mine
  typeset -A mgr_of
  for (( i = 1; i < $#spec; i += 2 )); do
    for d in $spec[i+1]/*(/n); do
      [[ ${d:t} == v#<->.<->.<-> ]] || continue
      all+=($d); mgr_of[$d]=$spec[i]
    done
  done
  (( $#all > 1 )) || return
  managers=(${(u)${(@v)mgr_of}})

  # defaults
  [[ -r $HOME/.nvm/alias/default ]] && wanted+=($(<$HOME/.nvm/alias/default))
  line=$(grep -o '"runtime": *"[^"]*"' $volta/tools/user/platform.json 2>/dev/null | head -1)
  [[ -n $line ]] && wanted+=(${line//[^0-9.]/})
  line=$(grep -E '^[[:space:]]*node(js)?[[:space:]]*=' $HOME/.config/mise/config.toml 2>/dev/null | head -1)
  [[ -n $line ]] && wanted+=(${line//[^0-9.]/})
  for link in $fnm_dir/aliases/default "$HOME/Library/Application Support/fnm/aliases/default"; do
    [[ -e $link ]] || continue
    d=${link:A}; [[ ${d:t} == installation ]] && d=${d:h}
    keep+=($d)
  done
  # pins in your projects and home folder
  for f in $HOME/.nvmrc(N) $HOME/.node-version(N) $HOME/.tool-versions(N) ${(f)"$(find $PROJECT_ROOTS -maxdepth 4 \
             \( -name node_modules -o -name .git \) -prune -o \( -name .nvmrc -o -name .node-version -o -name .tool-versions \) \
             -type f -print 2>/dev/null)"}; do
    if [[ ${f:t} == .tool-versions ]]; then
      wanted+=(${${(M)${(f)"$(<$f)"}:#(nodejs|node) *}#* })
    else
      wanted+=($(<$f))
    fi
  done
  for w in $wanted; do
    w=${w#v}
    if [[ $w == <->.<->.<-> ]]; then
      for d in $all; do [[ ${${d:t}#v} == $w ]] && keep+=($d); done
    elif [[ ${w%%.*} == <-> ]]; then
      for i in $managers; do
        mine=(); for d in $all; do [[ $mgr_of[$d] == $i && ${${d:t}#v} == ${w%%.*}.* ]] && mine+=($d); done
        (( $#mine )) && keep+=(${${(@On)mine}[1]})
      done
    fi
  done
  # the node on PATH, and each manager's newest version
  for d in $all; do [[ ${commands[node]:A} == $d/* ]] && keep+=($d); done
  for i in $managers; do
    mine=(); for d in $all; do [[ $mgr_of[$d] == $i ]] && mine+=($d); done
    keep+=(${${(@On)mine}[1]})
  done

  for d in $all; do (( ${keep[(Ie)$d]} )) || drop+=($d); done
  (( $#drop )) || return
  local -a names kept
  for d in $drop; do names+=("${d:t}${${managers[2]:+ ($mgr_of[$d])}}"); done
  for d in ${(u)keep}; do kept+=("${d:t}${${managers[2]:+ ($mgr_of[$d])}}"); done
  add_extra old-node-versions "Old Node versions: ${(j:, :)names}" $(kb_of $drop) rm "${(F)drop}" \
    "keeps ${(j:, :)kept} (defaults, newest, the node on PATH, and pinned versions)"
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
  load_catalog extras
  extra_ios_simulators
  extra_chrome_ai_model
  extra_claude_vm
  extra_android_emulators
  extra_ollama_models
  extra_old_node
  extra_docker_unused
}
