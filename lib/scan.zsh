# makleen: running the scanners and the default selection. Sourced by the makleen entry script.

# Report only: apps nobody has opened in a while.
collect_unused_apps() {
  local app raw t days
  for app in /Applications/*.app; do
    raw=$(mdls -raw -name kMDItemLastUsedDate $app 2>/dev/null)
    [[ -n $raw && $raw != "(null)" ]] || continue
    strftime -r -s t '%Y-%m-%d %H:%M:%S %z' $raw 2>/dev/null || continue
    days=$(( (EPOCHSECONDS - t) / 86400 ))
    (( days >= UNUSED_APP_DAYS )) && UNUSED_APPS+=("$(kb_of $app)"$'\t'"${app:t:r}"$'\t'"$days")
  done
}

category_kb() {  # category [picked-only] -> REPLY
  local i
  REPLY=0
  for (( i = 1; i <= $#I_CAT; i++ )); do
    [[ $I_CAT[i] == $1 ]] || continue
    [[ -n $2 ]] && (( ! PICK[i] )) && continue
    (( REPLY += I_KB[i] ))
  done
}

collect_all() {
  local cat t0
  chatty && print -u2 "${BOLD}makleen${RESET} ${DIM}· looking for space to reclaim${RESET}"
  for cat in $CATS; do
    t0=$EPOCHREALTIME
    collect_$cat
    progress_done
    if chatty; then
      category_kb $cat
      printf "  ${GREEN}✓${RESET} %-34s %9s  ${DIM}%.0fs${RESET}\n" ${CATEGORY_NAME[$cat]} "$(human $REPLY)" $(( EPOCHREALTIME - t0 )) >&2
    fi
  done
  (( $#CATS == $#ALL_CATEGORIES )) && { progress "Checking app usage…"; collect_unused_apps; progress_done }
  local i n
  local -A seen
  for (( i = 1; i <= $#I_KB; i++ )); do
    I_SIZE[i]=$(human $I_KB[i])
    n=$(( ++seen[$I_ID[i]] )); (( n > 1 )) && I_ID[i]+=-$n
  done
  init_selection
}

# Default selection: confirmed items on, [review] and optional off, items of running apps locked.
init_selection() {
  local i id cat needle=${(L)ONLY} procs=$(ps -axo command=)
  for (( i = 1; i <= $#I_CAT; i++ )); do
    PICK[i]=0 LOCK[i]=
    if [[ $I_GUARD[i] == @fda ]]; then  # a condition, not a process name
      has_fda || { LOCK[i]="needs Full Disk Access"; continue }
    elif [[ -n $I_GUARD[i] && $procs == *"$I_GUARD[i]"* ]]; then LOCK[i]="in use"; continue; fi
    if [[ -n $ONLY ]] || (( $#IDS )); then
      (( ! $#IDS || ${IDS[(Ie)$I_ID[i]]} )) || continue
      [[ -z $ONLY || ${(L)I_LABEL[i]} == *$needle* || ${(L)I_TARGET[i]} == *$needle* ]] && PICK[i]=1
    else
      [[ -z $I_FLAG[i] ]] && PICK[i]=1
    fi
  done
  for id in $IDS; do
    i=${I_ID[(Ie)$id]}
    if (( ! i )); then warn "no item with id $id; it may be gone, run makleen scan --json again"
    elif [[ -n $LOCK[i] ]]; then warn "$id can't be cleaned now: $LOCK[i]"
    fi
  done
  ROWS=()
  for cat in $CATS; do
    sorted_indices $cat
    (( $#reply )) && ROWS+=(h:$cat $reply)
  done
}

sorted_indices() {  # category -> $reply, largest first
  local i
  local -a rows
  for (( i = 1; i <= $#I_CAT; i++ )); do [[ $I_CAT[i] == $1 ]] && rows+=("$I_KB[i] $i"); done
  (( $#rows )) || { reply=(); return }
  reply=(${${(f)"$(print -l $rows | sort -rn)"}#* })
}

item_tag() {  # index -> REPLY tag text, REPLY2 its color
  REPLY= REPLY2=
  if [[ -n $LOCK[$1] ]]; then REPLY=$LOCK[$1] REPLY2=$DIM
  elif [[ $I_FLAG[$1] == review ]]; then REPLY="check first" REPLY2=$YELLOW
  elif [[ $I_FLAG[$1] == optional ]]; then REPLY="optional" REPLY2=$DIM
  fi
}
