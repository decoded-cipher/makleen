# makkili: quarantine listing, restore and purge. Sourced by the makkili entry script.

cmd_quarantine() {
  local b
  local -a batches=($QUARANTINE_DIR/*(/))
  (( $#batches )) || { say "Quarantine is empty."; return }
  for b in $batches; do
    printf "  %s  %9s  %s\n" ${b:t} "$(human $(kb_of $b))" "$(sed "s|^$HOME|~|" $b/MANIFEST 2>/dev/null | head -3 | paste -sd ' ' -)"
  done
}

cmd_restore() {
  local b=$QUARANTINE_DIR/$1 src left=0 kb
  local -a details
  [[ -n $1 && -f $b/MANIFEST ]] || die "no such batch: ${1:-?} (see: makkili quarantine)"
  kb=$(kb_of $b)
  log_open restore
  for src in ${(f)"$(<$b/MANIFEST)"}; do
    [[ -e $b$src ]] || continue
    if [[ -e $src ]]; then item_warn "$src exists again, leaving the copy in quarantine"; left=1; continue; fi
    if mkdir -p ${src:h} && mv -- $b$src $src; then
      say "restored ${src/#$HOME/$TILDE}"; details+=("restored ${src/#$HOME/$TILDE}")
    else
      item_warn "could not restore $src"; left=1
    fi
  done
  local result=done
  (( left )) && result=partial || rm -rf -- $b
  log_entry $result $kb "restore batch $1" $details
  say "${DIM}Log: ${LOG_FILE/#$HOME/$TILDE}${RESET}"
}

cmd_purge() {
  local b age kb
  local -a batches=($QUARANTINE_DIR/*(/)) doomed
  for b in $batches; do
    age=$(( (EPOCHSECONDS - $(zstat +mtime $b)) / 86400 ))
    (( PURGE_ALL || age >= PURGE_DAYS )) && doomed+=($b)
  done
  (( $#doomed )) || { say "Nothing to purge (batches younger than $PURGE_DAYS days are kept; --all purges everything)."; return }
  confirm "Permanently delete ${#doomed} quarantine batch(es), $(human $(kb_of $doomed))?" || return
  log_open purge
  local -a was
  for b in $doomed; do
    kb=$(kb_of $b)
    was=(${(f)"$(sed "s|^$HOME|~|; s|^|was: |" $b/MANIFEST 2>/dev/null)"})
    if rm -rf -- $b; then
      say "purged ${b:t} ($(human $kb))"; log_entry done $kb "purge batch ${b:t}" $was
    else
      warn "could not fully delete ${b:t}"; log_entry partial $kb "purge batch ${b:t}" $was
    fi
  done
  log ""
  log "free space: $(human $(free_kb))"
  say "${DIM}Log: ${LOG_FILE/#$HOME/$TILDE}${RESET}"
}
