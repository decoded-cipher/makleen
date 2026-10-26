# makleen: the makleen scan report. Sourced by the makleen entry script.

print_report() {
  local W=$(term_width) cat i shown row
  say ""
  disk_bar 24
  say " ${BOLD}makleen${RESET}  $REPLY"
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
  say " ${DIM}selected = what \`makleen\` preselects in the checklist; you can change it there${RESET}"

  for cat in $CATS; do
    sorted_indices $cat
    (( $#reply )) || continue
    say ""
    say " ${BOLD}${CATEGORY_NAME[$cat]}${RESET}  ${DIM}${CATEGORY_HINT[$cat]}${RESET}"
    shown=0
    for i in $reply; do
      if (( ! SHOW_ALL && shown >= 10 )); then say "   ${DIM}… $(( $#reply - shown )) more (makleen scan --all)${RESET}"; break; fi
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
  (( q )) && say " ${DIM}Quarantine holds $(human $q). Free it with \`makleen purge\`.${RESET}"
  for row in $SKIPPED; do say " ${DIM}Note: $row${RESET}"; done
  if (( $#UNUSED_APPS )); then
    say ""
    say " ${BOLD}Apps not opened in $UNUSED_APP_DAYS+ days${RESET}  ${DIM}report only, uninstall them yourself${RESET}"
    for row in ${(f)"$(print -l $UNUSED_APPS | sort -rn)"}; do
      printf "   %9s  %s  ${DIM}%sd${RESET}\n" "$(human ${row%%$'\t'*})" "${${row#*$'\t'}%$'\t'*}" "${row##*$'\t'}"
    done
  fi
  if ! has_fda; then
    say ""
    say " ${DIM}No Full Disk Access: Mail, Messages, Photos, Safari and the Trash were not measured, and"
    say " leftovers in app containers can't be moved. Grant it to your terminal in"
    say " System Settings → Privacy & Security → Full Disk Access.${RESET}"
  fi
}

print_json() {
  local row i t sep= flag lock
  local -a df=($(df -k $HOME | awk 'NR == 2 { print $3, $4 }')) paths f
  say "{"
  say "  \"version\": \"$VERSION\","
  say "  \"disk\": {\"used_kb\": $df[1], \"free_kb\": $df[2]},"
  has_fda && say '  "full_disk_access": true,' || say '  "full_disk_access": false,'
  say "  \"items\": ["
  for row in $ROWS; do
    [[ $row == h:* ]] && continue
    i=$row paths=()
    [[ $I_KIND[i] == cmd ]] || for t in ${(f)I_TARGET[i]}; do json_str $t; paths+=($REPLY); done
    case $I_FLAG[i] in review) flag='"check-first"' ;; optional) flag='"optional"' ;; *) flag=null ;; esac
    if [[ -n $LOCK[i] ]]; then json_str $LOCK[i]; lock=$REPLY; else lock=null; fi
    f=()
    json_str $I_ID[i];    f+=("\"id\": $REPLY")
    f+=("\"category\": \"$I_CAT[i]\"")
    json_str $I_LABEL[i]; f+=("\"label\": $REPLY")
    f+=("\"size_kb\": $I_KB[i]" "\"size\": \"$I_SIZE[i]\"")
    f+=("\"action\": \"${${I_KIND[i]/rm/delete}/cmd/command}\"")
    f+=("\"paths\": [${(j:, :)paths}]")
    if [[ $I_KIND[i] == cmd ]]; then json_str $I_TARGET[i]; f+=("\"command\": $REPLY"); fi
    json_str $I_NOTE[i];  f+=("\"note\": $REPLY")
    f+=("\"flag\": $flag" "\"locked\": $lock" "\"preselected\": ${${PICK[i]/1/true}/0/false}")
    say "$sep    {${(j:, :)f}}"
    sep=,
  done
  say "  ],"
  sep=
  say "  \"notes\": ["
  for row in $SKIPPED; do json_str $row; say "$sep    $REPLY"; sep=,; done
  say "  ],"
  sep=
  say "  \"unused_apps\": ["
  for row in $UNUSED_APPS; do
    json_str ${${row#*$'\t'}%$'\t'*}
    say "$sep    {\"name\": $REPLY, \"size_kb\": ${row%%$'\t'*}, \"days_unused\": ${row##*$'\t'}}"
    sep=,
  done
  say "  ],"
  say "  \"kept_active_kb\": $ACTIVE_KB,"
  say "  \"quarantine_kb\": $(kb_of $QUARANTINE_DIR)"
  say "}"
}
