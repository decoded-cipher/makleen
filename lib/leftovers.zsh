# makleen: leftovers of uninstalled apps in ~/Library. Sourced by the makleen entry script.

# A plain folder name is Apple's when macOS ships a framework, app, daemon or launch job by that name.
apple_component() {
  local n=$1 f
  for f in /System/Library/{Frameworks,PrivateFrameworks}/$n.framework /System/Library/CoreServices/$n.app \
           /System/Applications/$n.app /System/Applications/Utilities/$n.app /usr/libexec/$n /usr/sbin/$n \
           /System/Library/CoreServices/$n /System/Library/PrivateFrameworks/*.framework/Support/$n \
           /System/Library/PrivateFrameworks/*.framework/Versions/A/Support/$n; do
    [[ -e $f ]] && return 0
  done
  local -a jobs=(/System/Library/Launch{Agents,Daemons}/com.apple.(#i)$n.plist
                 /System/Library/Launch{Agents,Daemons}/com.apple.*.(#i)$n.plist)
  (( $#jobs ))
}

# Apple folders that apple_component can't recognise (normalized), plus tool dirs that are never app data.
SYSTEM_NAMES=(addressbook animoji appstore assistant automator baseband callhistorydb callhistorytransactions
  cloudkit clouddocs contactsd controlcenter coresimulator crashreporter defaultstore defaultstoreshm
  defaultstorewal diagnosticreports differentialprivacy diskimages facetime familycircle fileprovider fsckhfs
  geoservices homebrew homeenergyd icdd icloud icloudmailagent identityservice identityservicesd
  ilifemediabrowser instruments knowledge locationaccessstored networkserviceproxy photossearchaapbz
  privacypreservingmeasurement privatecloudcomputed sirittsservice spotlight stickersd tipsd)
GENERIC_TOKENS=(app apps beta browser client desktop helper mac macos stable)
# Folders named after the app; fully classified.
LEFTOVER_PRIMARY=("Application Support" "Application Support/Caches" Caches Containers "Group Containers" Logs)
# Small per-bundle-id files; only reported when macOS remembers the id as an app that is now gone.
LEFTOVER_SATELLITE=(Preferences "Saved Application State" HTTPStorages WebKit "Application Scripts" Cookies)

typeset -A APP_IDS APP_PATH_BY_ID APP_TOKENS APP_TEAMS LS_IDS LS_NAMES LS_LIVE
typeset -a APP_PATHS VENDORS

index_installed() {
  (( $#APP_PATHS )) && return  # already indexed in this run
  local app plist id t
  local -a parts
  for app in /Applications/*.app /Applications/*/*.app $HOME/Applications/*.app $HOME/Applications/*/*.app \
             /System/Applications/*.app /System/Applications/*/*.app /System/Library/CoreServices/*.app; do
    plist=$app/Contents/Info.plist
    [[ -r $plist ]] || continue
    APP_PATHS+=($app)
    id=$(plutil -extract CFBundleIdentifier raw -o - $plist 2>/dev/null)
    if [[ -n $id ]]; then
      APP_IDS[${(L)id}]=${app:t:r}
      APP_PATH_BY_ID[${(L)id}]=$app
      parts=(${(s:.:)${(L)id}})
      VENDORS+=($parts[1].$parts[2])
    fi
    for t in ${app:t:r} "$(plutil -extract CFBundleName raw -o - $plist 2>/dev/null)" \
             "$(plutil -extract CFBundleExecutable raw -o - $plist 2>/dev/null)" ${id##*.}; do
      norm $t
      [[ -n $REPLY ]] && (( ! ${GENERIC_TOKENS[(Ie)$REPLY]} )) && APP_TOKENS[$REPLY]=${app:t:r}
    done
  done
}

# Team IDs prefix group containers (UBF8T346G9.Office); only computed when one shows up.
index_teams() {
  [[ -n ${APP_TEAMS[_done]} ]] && return
  local app team
  for app in $APP_PATHS; do
    [[ $app == /System/* ]] && continue
    team=$(codesign -dv $app 2>&1 | sed -n 's/^TeamIdentifier=//p')
    [[ -n $team && $team != "not set" ]] && APP_TEAMS[$team]=${app:t:r}
  done
  APP_TEAMS[_done]=1
}

# LaunchServices remembers apps that were once registered, including deleted ones,
# which tells us both that a folder belonged to a real app and what that app was called.
# It also records where each copy lived; if any copy still exists (helper apps nested
# inside installed apps, for example), the app is not gone.
index_launchservices() {
  local -a rows
  local row key name app_path
  rows=(${(f)"$($LSREGISTER -dump 2>/dev/null | awk '
    /^-+$/      { name = ""; path = ""; next }
    /^path: /   { sub(/^path: +/, ""); sub(/ \(0x[0-9a-f]+\)$/, ""); path = $0; next }
    /^name: /   { sub(/^name: +/, ""); sub(/ Helper.*$/, ""); name = $0
                  k = tolower(name); gsub(/[^a-z0-9]/, "", k)
                  if (k != "") print "N" k "\t" name "\t" path
                  next }
    /^identifier: / && name != "" { sub(/^identifier: +/, ""); print "I" tolower($0) "\t" name "\t" path }' | sort -u)"})
  for row in $rows; do
    key=${row%%$'\t'*} name=${${row#*$'\t'}%$'\t'*} app_path=${row##*$'\t'}
    [[ -n $app_path && -e $app_path ]] && LS_LIVE[$key]=1
    case $key in
      N*) LS_NAMES[${key#N}]=$name ;;
      I*) LS_IDS[${key#I}]=$name ;;
    esac
  done
}

looks_like_app_data() {  # browser/Electron profile layout
  local h
  for h in "Local Storage" GPUCache "Code Cache" blob_storage Crashpad "Session Storage" IndexedDB profiles.ini Profiles; do
    [[ -e $1/$h ]] && return 0
  done
  return 1
}

# Sets CL_STATE (installed|skip|orphan|review), CL_LABEL, CL_WHY.
classify_entry() {  # location entry fullpath satellite
  local loc=$1 name=$2 full=$3 satellite=$4 base=$2 team= lower t i probe first
  local -a parts
  CL_STATE=skip CL_LABEL=$name CL_WHY=
  [[ $name == .* ]] && return
  untouchable $full && return
  base=${base%.plist}; base=${base%.savedState}; base=${base%.binarycookies}; base=${base%-updater}
  [[ $loc == Logs ]] && base=${base%%.log*}
  if [[ $loc == "Group Containers" && $base =~ '^[A-Z0-9]{10}\.' ]]; then team=${base%%.*}; base=${base#*.}; fi
  base=${base#group.}
  lower=${(L)base}
  [[ $lower == *com.apple* || $lower == apple* ]] && return
  [[ $lower == is.workflow* ]] && return  # Shortcuts still uses the ids of Workflow, the app Apple bought
  norm $base; t=$REPLY
  [[ -z $t ]] && return
  (( ${SYSTEM_NAMES[(Ie)$t]} )) && return
  for i in $LEFTOVER_IGNORE; do [[ $name == ${~i} ]] && return; done

  if [[ -n $team ]]; then
    index_teams
    [[ -n ${APP_TEAMS[$team]} ]] && { CL_STATE=installed; return }
  fi

  if [[ $lower =~ '^[a-z0-9_-]+(\.[a-z0-9_-]+){2,}$' ]]; then  # bundle id
    for i in ${(k)APP_IDS}; do
      [[ $lower == $i || $lower == $i.* || $i == $lower.* ]] && { CL_STATE=installed; return }
    done
    probe=$lower
    while [[ $probe == *.*.* ]]; do  # foo.bar.app.helper -> foo.bar.app
      [[ -n ${LS_LIVE[I$probe]} ]] && { CL_STATE=installed; return }
      if [[ -n ${LS_IDS[$probe]} ]]; then
        CL_STATE=orphan CL_LABEL=${LS_IDS[$probe]} CL_WHY="app registered with macOS earlier, now gone"
        return
      fi
      probe=${probe%.*}
    done
    (( satellite )) && return
    parts=(${(s:.:)lower})
    if (( ${VENDORS[(Ie)$parts[1].$parts[2]]} )); then
      CL_STATE=review CL_WHY="same vendor as an installed app"
    else
      CL_STATE=orphan CL_WHY="no installed app has this bundle id"
    fi
    return
  fi
  (( satellite )) && return

  # Plain folder names
  apple_component $base && return
  [[ -n ${APP_TOKENS[$t]} ]] && { CL_STATE=installed; return }
  for i in ${(k)APP_TOKENS} ${VENDORS#*.}; do
    (( ${#i} >= 4 )) && [[ $t == $i* ]] && { CL_STATE=installed; return }  # BraveSoftware, vscode-cpptools
  done
  [[ -n ${LS_LIVE[N$t]} ]] && { CL_STATE=installed; return }
  if [[ -n ${LS_NAMES[$t]} ]]; then
    CL_STATE=orphan CL_LABEL=${LS_NAMES[$t]} CL_WHY="app registered with macOS earlier, now gone"
    return
  fi
  first=${lower%%[-_. ]*}
  if has $lower || has $first; then return; fi  # belongs to an installed command-line tool
  if looks_like_app_data $full; then
    CL_STATE=orphan CL_WHY="app profile data, no such app installed"
    return
  fi
  for i in ${(k)APP_TOKENS}; do
    (( ${#t} >= 4 )) && [[ $i == *$t* ]] && { CL_STATE=review CL_WHY="name resembles installed ${APP_TOKENS[$i]}"; return }
  done
  CL_STATE=review CL_WHY="owner unknown, possibly a command-line tool"
}

collect_leftovers() {
  progress "Indexing installed apps…"
  index_installed
  progress "Reading the LaunchServices registry…"
  index_launchservices
  load_claims
  typeset -A g_kb g_paths g_state g_why
  local loc full sat kb label fda=1 suffix=" (app container)"
  has_fda || fda=0
  for loc in $LEFTOVER_PRIMARY $LEFTOVER_SATELLITE; do
    sat=$(( ${LEFTOVER_SATELLITE[(Ie)$loc]} > 0 ))
    progress "Scanning ~/Library/$loc…"
    for full in "$HOME/Library/$loc"/*; do
      [[ $loc == "Application Support" && ${full:t} == Caches ]] && continue  # scanned as its own location
      [[ -n ${CLAIMED[$full]} ]] && continue  # a catalogued cache, reported under caches
      classify_entry $loc ${full:t} $full $sat
      [[ $CL_STATE == (orphan|review) ]] || continue
      kb=$(kb_of $full)
      label=$CL_LABEL
      # macOS refuses to move ~/Library/Containers without Full Disk Access: keep those apart
      (( fda )) || [[ $full != $HOME/Library/Containers/* ]] || label+=$suffix
      g_kb[$label]=$(( ${g_kb[$label]:-0} + kb ))
      g_paths[$label]+=$full$'\n'
      [[ $CL_STATE == review || -z ${g_state[$label]} ]] && g_state[$label]=$CL_STATE
      [[ -n ${g_why[$label]} ]] || g_why[$label]=$CL_WHY
    done
  done
  # Apps under 1 MB are folded into one line per state so the list stays readable.
  local -a paths tiny_paths tiny_names tiny_rpaths tiny_rnames tiny_cpaths tiny_cnames
  local tiny_kb=0 tiny_rkb=0 tiny_ckb=0 guard need_fda="macOS lets makleen move app containers only with Full Disk Access"
  for label in ${(k)g_kb}; do
    paths=(${(f)g_paths[$label]})
    if (( ${g_kb[$label]} < 1024 )); then
      if [[ $label == *$suffix ]]; then
        tiny_cpaths+=($paths) tiny_cnames+=(${label%$suffix}); (( tiny_ckb += ${g_kb[$label]} ))
      elif [[ ${g_state[$label]} == orphan ]]; then
        tiny_paths+=($paths) tiny_names+=($label); (( tiny_kb += ${g_kb[$label]} ))
      else
        tiny_rpaths+=($paths) tiny_rnames+=($label); (( tiny_rkb += ${g_kb[$label]} ))
      fi
      continue
    fi
    guard=; [[ $label == *$suffix ]] && guard=@fda
    add_item leftovers "$label" "${g_kb[$label]}" quarantine "${(F)paths}" \
      "${g_why[$label]} · ${#paths} path(s)${guard:+ · $need_fda}" "${${g_state[$label]}:#orphan}" "$guard"
  done
  (( $#tiny_names )) && add_item leftovers "Small leftovers of ${#tiny_names} app${${tiny_names[2]:+s}}" $tiny_kb quarantine \
    "${(F)tiny_paths}" "${(j:, :)${(@oi)tiny_names}}"
  (( $#tiny_rnames )) && add_item leftovers "Small unidentified leftovers (${#tiny_rnames})" $tiny_rkb quarantine \
    "${(F)tiny_rpaths}" "${(j:, :)${(@oi)tiny_rnames}}" review
  (( $#tiny_cnames )) && add_item leftovers "Small leftovers in app containers (${#tiny_cnames})" $tiny_ckb quarantine \
    "${(F)tiny_cpaths}" "$need_fda · ${(j:, :)${(@oi)tiny_cnames}}" "" @fda
}
