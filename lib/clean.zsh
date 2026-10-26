# makleen: cleaning the selected items. Sourced by the makleen entry script.

# Warnings while cleaning an item go to the terminal and into that item's log entry.
item_warn() { print -ru2 -- "makleen: $*"; details+=("warning: $*") }

quarantine_path() {
  local src=$1 dest
  [[ -e $src || -L $src ]] || return 0
  safe_path $src || { item_warn "refusing to move $src"; return 1 }
  if [[ -z $BATCH ]]; then
    BATCH=$QUARANTINE_DIR/$(strftime %Y%m%d-%H%M%S $EPOCHSECONDS)
    mkdir -p $BATCH
  fi
  dest=$BATCH$src
  mkdir -p ${dest:h} && mv -- $src $dest 2>/dev/null ||
    { item_warn "could not move $src (macOS may protect it; Full Disk Access helps)"; return 1 }
  print -r -- $src >> $BATCH/MANIFEST
}

execute_item() {  # index position count
  local i=$1 t head out rc good=0 bad=0 result
  local -a details
  head=$(printf "  ${DIM}[%${#3}d/%d]${RESET}" $2 $3)
  if [[ -n $I_GUARD[i] ]] && running $I_GUARD[i]; then
    say "$head ${DIM}–  skipped, in use: $I_LABEL[i]${RESET}"
    log_entry skipped $I_KB[i] "[$I_CAT[i]] $I_LABEL[i]" "in use: $I_GUARD[i] is running"
    return
  fi
  [[ -t 1 ]] && print -n "$head ${DIM}…  $I_SIZE[i]  $I_LABEL[i]${RESET}"
  case $I_KIND[i] in
    rm)
      for t in ${(f)I_TARGET[i]}; do
        [[ -e $t || -L $t ]] || continue
        safe_path $t || { item_warn "refusing to delete $t"; (( bad++ )); continue }
        if rm -rf -- $t 2>/dev/null || { chmod -R u+w -- $t 2>/dev/null; rm -rf -- $t 2>/dev/null }; then
          details+=("deleted ${t/#$HOME/$TILDE}"); (( good++ ))
        else
          item_warn "could not fully delete $t"; (( bad++ ))
        fi
      done ;;
    quarantine)
      for t in ${(f)I_TARGET[i]}; do
        if quarantine_path $t; then details+=("quarantined ${t/#$HOME/$TILDE}"); (( good++ )); else (( bad++ )); fi
      done ;;
    cmd)
      details+=("ran: $I_TARGET[i]")
      out=$( ( eval $I_TARGET[i] ) 2>&1 </dev/null ); rc=$?
      [[ -n $out ]] && details+=("${(@)${(f)out}/#/│ }")
      if (( rc )); then details+=("exit status $rc"); (( bad++ )); else (( good++ )); fi ;;
  esac
  if (( ! bad )); then result=done
  elif (( good )); then result=partial
  else result=failed
  fi
  log_entry $result $I_KB[i] "[$I_CAT[i]] $I_LABEL[i]" $details
  [[ -t 1 ]] && print -n $'\r\e[K'
  case $result in
    done)    say "$head ${GREEN}✓${RESET}  ${(l:9:)I_SIZE[i]}  $I_LABEL[i]" ;;
    partial) say "$head ${YELLOW}!${RESET}  ${(l:9:)I_SIZE[i]}  $I_LABEL[i] ${DIM}(partly done, see the log)${RESET}" ;;
    failed)  say "$head ${YELLOW}✗${RESET}  ${(l:9:)I_SIZE[i]}  $I_LABEL[i] ${DIM}(failed, see the log)${RESET}" ;;
  esac
}

do_clean() {
  (( $#ROWS )) || { say "Nothing to clean."; return }
  if (( ! ASSUME_YES && ! $#IDS )) && [[ -t 0 && -t 1 ]]; then
    pick_items || { say "Quit, nothing changed."; return }
  elif (( ! ASSUME_YES && ! DRY_RUN )) && [[ ! -t 0 || ! -t 1 ]]; then
    die "the checklist needs a terminal; use --dry-run to see the plan, --yes to clean the preselected items"
  fi

  local cat i t total=0 n
  local -a sel
  for cat in $CATS; do
    sorted_indices $cat
    for i in $reply; do (( PICK[i] )) && { sel+=($i); (( total += I_KB[i] )) }; done
  done
  (( $#sel )) || { say "Nothing selected, nothing changed."; return }

  say ""
  say " ${BOLD}Cleaning $(human $total) in ${#sel} item(s)${RESET}"
  for cat in $CATS; do
    n=0
    for i in $sel; do [[ $I_CAT[i] == $cat ]] && (( n++ )); done
    (( n )) || continue
    category_kb $cat picked
    printf "   %-36s %3d item(s) %10s  ${DIM}%s${RESET}\n" ${CATEGORY_NAME[$cat]} $n "$(human $REPLY)" ${CATEGORY_HINT[$cat]}
    if (( DRY_RUN )); then
      for i in $sel; do
        [[ $I_CAT[i] == $cat ]] || continue
        printf "     %9s  %s\n" $I_SIZE[i] $I_LABEL[i]
        if [[ $I_KIND[i] == cmd ]]; then say "                ${DIM}runs: $I_TARGET[i]${RESET}"
        else for t in ${(f)I_TARGET[i]}; do say "                ${DIM}${t/#$HOME/$TILDE}${RESET}"; done
        fi
      done
    fi
  done
  (( DRY_RUN )) && { say ""; say " Dry run: nothing changed."; return }
  say ""
  confirm " Go ahead?" || { say " Cancelled, nothing changed."; return }

  log_open clean
  log "cleaning $(human $total) in ${#sel} item(s)"
  log ""
  local before=$(free_kb) k=0
  BATCH=
  say ""
  for i in $sel; do execute_item $i $(( ++k )) $#sel; done
  local after=$(free_kb)
  log ""
  log "free space: $(human $before) → $(human $after)"
  [[ -n $BATCH ]] && log "quarantine batch: ${BATCH:t}"
  say ""
  say " ${BOLD}Free space: $(human $before) → $(human $after)${RESET}"
  if [[ -n $BATCH ]]; then
    say " ${DIM}Leftovers went to quarantine (${BATCH:t}) and still take space until purged."
    say " Undo: makleen restore ${BATCH:t}   ·   free it: makleen purge --all${RESET}"
  fi
  say " ${DIM}Log: ${LOG_FILE/#$HOME/$TILDE}${RESET}"
}
