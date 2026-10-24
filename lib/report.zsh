# makkili: the makkili scan report. Sourced by the makkili entry script.

print_report() {
  local W=$(term_width) cat i shown row
  say ""
  disk_bar 24
  say " ${BOLD}makkili${RESET}  $REPLY"
  say ""
  printf " ${DIM}%-36s %10s %12s${RESET}\n" "" "found" "selected"
  local all=0 picked=0
  for cat in $CATS; do
    category_kb $cat; local f=$REPLY
    category_kb $cat picked
    printf " %-36s %10s %12s\n" ${CATEGORY_NAME[$cat]} "$(human $f)" "$(human $REPLY)"
    (( all += f, picked += REPLY ))
  done
  printf " ${BOLD}%-36s %10s %12s${RESET}\n" "Total" "$(human $all)" "$(human $picked)"
  say " ${DIM}selected = what \`makkili\` preselects in the checklist; you can change it there${RESET}"

  for cat in $CATS; do
    sorted_indices $cat
    (( $#reply )) || continue
    say ""
    say " ${BOLD}${CATEGORY_NAME[$cat]}${RESET}  ${DIM}${CATEGORY_HINT[$cat]}${RESET}"
    shown=0
    for i in $reply; do
      if (( ! SHOW_ALL && shown >= 10 )); then say "   ${DIM}… $(( $#reply - shown )) more (makkili scan --all)${RESET}"; break; fi
      item_tag $i
      local tag=$REPLY tagc=$REPLY2
      fit $I_LABEL[i] $(( W - 16 - (${#tag} ? ${#tag} + 2 : 0) ))
      printf "   %9s  %s%s\n" $I_SIZE[i] $REPLY "${tag:+  $tagc$tag$RESET}"
      fit $I_NOTE[i] $(( W - 15 ))
      [[ -n $REPLY ]] && say "              ${DIM}$REPLY${RESET}"
      (( shown++ ))
    done
  done

  say ""
  (( ACTIVE_KB )) && say " ${DIM}Kept: $(human $ACTIVE_KB) of build folders in projects used in the last $INACTIVE_DAYS days${RESET}"
  local q=$(kb_of $QUARANTINE_DIR)
  (( q )) && say " ${DIM}Quarantine holds $(human $q). Free it with \`makkili purge\`.${RESET}"
  for row in $SKIPPED; do say " ${DIM}Note: $row${RESET}"; done
  if (( $#UNUSED_APPS )); then
    say ""
    say " ${BOLD}Apps not opened in $UNUSED_APP_DAYS+ days${RESET}  ${DIM}report only, uninstall them yourself${RESET}"
    for row in ${(f)"$(print -l $UNUSED_APPS | sort -rn)"}; do
      printf "   %9s  %s  ${DIM}%sd${RESET}\n" "$(human ${row%%$'\t'*})" "${${row#*$'\t'}%$'\t'*}" "${row##*$'\t'}"
    done
  fi
  if ! ls $HOME/Library/Mail >/dev/null 2>&1; then
    say ""
    say " ${DIM}No Full Disk Access: Mail, Messages, Photos, Safari and the Trash were not measured."
    say " Grant it in System Settings → Privacy & Security → Full Disk Access.${RESET}"
  fi
}
