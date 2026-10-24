# makkili: build folders in projects that have not been used lately. Sourced by the makkili entry script.

ARTIFACT_NAMES=(node_modules .next .nuxt .svelte-kit .turbo .parcel-cache .angular .expo
  .venv venv env Pods build .cxx .gradle target .dart_tool .terraform)
FIND_NAMES=()
for n in $ARTIFACT_NAMES; do FIND_NAMES+=(-name $n -o); done
FIND_NAMES[-1]=()
unset n

# A folder only counts as regenerable when the build system that produces it sits right next to it;
# matching on the name alone would also hit source folders called build/ or env/.
is_artifact() {
  local d=$1 p=${1:h}
  local -a tf
  case ${d:t} in
    node_modules|.next|.nuxt|.svelte-kit|.turbo|.parcel-cache|.angular|.expo) [[ -f $p/package.json ]] ;;
    .venv|venv|env) [[ -f $d/pyvenv.cfg ]] ;;
    Pods)           [[ -f $p/Podfile ]] ;;
    build)          [[ -f $p/build.gradle || -f $p/build.gradle.kts || -f $p/pubspec.yaml || ( ${p:t} == ios && -f $p/Podfile ) ]] ;;
    .cxx|.gradle)   [[ -f $p/build.gradle || -f $p/build.gradle.kts || -f $p/settings.gradle || -f $p/settings.gradle.kts ]] ;;
    target)         [[ -f $p/Cargo.toml || -f $p/pom.xml ]] ;;
    .dart_tool)     [[ -f $p/pubspec.yaml ]] ;;
    .terraform)     tf=($p/*.tf); (( $#tf )) ;;
    *) return 1 ;;
  esac
}

restore_hint() {  # artifact project
  local d=$1 p=${1:h} proj=$2 dir
  case ${d:t} in
    node_modules)
      for dir in $p $proj; do
        [[ -f $dir/pnpm-lock.yaml ]] && { print "pnpm install"; return }
        [[ -f $dir/yarn.lock ]] && { print "yarn install"; return }
        [[ -f $dir/bun.lockb || -f $dir/bun.lock ]] && { print "bun install"; return }
      done
      print "npm install" ;;
    .venv|venv|env)
      if [[ -f $p/uv.lock ]]; then print "uv sync"
      elif [[ -f $p/poetry.lock ]]; then print "poetry install"
      else print "recreate ${d:t} + pip install"; fi ;;
    Pods)       print "pod install" ;;
    target)     [[ -f $p/Cargo.toml ]] && print "cargo build" || print "mvn package" ;;
    .dart_tool) print "flutter pub get" ;;
    .terraform) print "terraform init" ;;
    *)          print "rebuilds on next build" ;;
  esac
}

project_root() {  # nearest ancestor with .git, else the artifact's parent
  local d=${1:h}
  while [[ $d != / && $d != $HOME ]]; do
    [[ -e $d/.git ]] && { REPLY=$d; return }
    d=${d:h}
  done
  REPLY=${1:h}
}

typeset -A PROJ_ACTIVE
last_activity() {  # project -> epoch of the latest sign of use
  local proj=$1 t=0 x gitdir
  [[ -n ${PROJ_ACTIVE[$proj]} ]] && { REPLY=${PROJ_ACTIVE[$proj]}; return }
  if [[ -e $proj/.git ]]; then
    x=$(git -C $proj log -1 --format=%ct 2>/dev/null); (( x > t )) && t=$x
    gitdir=$(git -C $proj rev-parse --absolute-git-dir 2>/dev/null)
    # HEAD's reflog moves on commit, checkout, pull and rebase, not on the IDE's background git status
    [[ -f $gitdir/logs/HEAD ]] && { x=$(zstat +mtime $gitdir/logs/HEAD); (( x > t )) && t=$x }
  fi
  if (( t == 0 )); then  # no git history: newest file near the top of the project
    x=$(find $proj -maxdepth 3 \( -name .git -o $FIND_NAMES \) -prune -o -type f ! -name .DS_Store -print0 2>/dev/null |
        xargs -0 stat -f %m 2>/dev/null | sort -n | tail -1)
    t=${x:-0}
  fi
  PROJ_ACTIVE[$proj]=$t
  REPLY=$t
}

is_protected() {
  local pat
  for pat in $PROTECT; do [[ $1 == ${~pat} || ${1/#$HOME/$TILDE} == ${~pat} ]] && return 0; done
  return 1
}

# Folders in ~ holding at least two git repos within three levels. Desktop, Documents and Downloads
# are skipped because touching them makes macOS ask for permission; add them to PROJECT_ROOTS yourself.
detect_project_roots() {
  local d
  local -a gits
  for d in $HOME/*(/); do
    [[ ${d:t} == (Library|Applications|Desktop|Documents|Downloads|Movies|Music|Pictures|Public) ]] && continue
    gits=($d/.git $d/*/.git $d/*/*/.git $d/*/*/*/.git)
    (( $#gits >= 2 )) && PROJECT_ROOTS+=($d)
  done
}

collect_projects() {
  local root d proj rel kb t x age hint
  typeset -A p_kb p_paths p_age p_kinds p_hints p_root
  (( $#PROJECT_ROOTS )) || detect_project_roots
  (( $#PROJECT_ROOTS )) || { skip projects "no project folders found; set PROJECT_ROOTS in $CONFIG_FILE"; return }
  for root in $PROJECT_ROOTS; do
    [[ -d $root ]] || continue
    progress "Scanning projects in ${root/#$HOME/$TILDE}…"
    find $root \( -name .git -o -path $HOME/Library \) -prune -o -type d \( $FIND_NAMES \) -prune -print0 2>/dev/null |
    while IFS= read -r -d '' d; do
      is_artifact $d && ! untouchable $d || continue
      project_root $d; proj=$REPLY
      is_protected $proj && continue
      rel=${d#$proj/}
      # anything with committed files inside is part of the project, not a build artifact
      [[ -e $proj/.git && -n $(git -C $proj ls-files -- $rel 2>/dev/null | head -n1) ]] && continue
      last_activity $proj; t=$REPLY
      x=$(zstat +mtime $d); (( x > t )) && t=$x  # a fresh install or build also counts as use
      kb=$(kb_of $d)
      age=$(( (EPOCHSECONDS - t) / 86400 ))
      if (( age < INACTIVE_DAYS )); then (( ACTIVE_KB += kb )); continue; fi
      p_kb[$proj]=$(( ${p_kb[$proj]:-0} + kb ))
      p_paths[$proj]+=$d$'\n'
      p_age[$proj]=$age
      p_root[$proj]=$root
      p_kinds[$proj]+="$rel, "
      hint=$(restore_hint $d $proj)
      [[ ${p_hints[$proj]} == *"$hint, "* ]] || p_hints[$proj]+="$hint, "
    done
  done
  local label
  for proj in ${(k)p_kb}; do
    label=${proj#${p_root[$proj]}/}
    [[ $label == $proj ]] && label=${proj:t}
    add_item projects $label ${p_kb[$proj]} rm "${p_paths[$proj]%$'\n'}" \
      "idle ${p_age[$proj]}d · restore: ${p_hints[$proj]%, } · ${p_kinds[$proj]%, }"
  done
}
