# makkili: the interactive checklist. Sourced by the makkili entry script.

tui_size() {
  local s=$(stty size </dev/tty 2>/dev/null)
  TUI_H=${s%% *} TUI_W=${s##* }
  (( TUI_H >= 12 )) || TUI_H=24
  (( TUI_W >= 50 )) || TUI_W=80
}

tui_restore() { print -n $'\e[?25h\e[?1049l' >/dev/tty }

section_state() {  # category -> SEC_BOX SEC_ON SEC_N SEC_SEL SEC_ALL
  local i
  SEC_ON=0 SEC_N=0 SEC_SEL=0 SEC_ALL=0
  for (( i = 1; i <= $#I_CAT; i++ )); do
    [[ $I_CAT[i] == $1 ]] || continue
    (( SEC_ALL += I_KB[i] ))
    [[ -n $LOCK[i] ]] && continue
    (( SEC_N++ ))
    (( PICK[i] )) && (( SEC_ON++, SEC_SEL += I_KB[i] ))
  done
  if (( SEC_ON == 0 )); then SEC_BOX="[ ]"
  elif (( SEC_ON == SEC_N )); then SEC_BOX="${GREEN}[x]${RESET}"
  else SEC_BOX="${GREEN}[~]${RESET}"
  fi
}

tui_set_section() {  # everything on unless it already is, then everything off
  local i v
  section_state $1
  v=$(( SEC_ON < SEC_N ))
  for (( i = 1; i <= $#I_CAT; i++ )); do
    [[ $I_CAT[i] == $1 && -z $LOCK[i] ]] && PICK[i]=$v
  done
}

tui_toggle() {
  local row=$ROWS[CUR]
  if [[ $row == h:* ]]; then tui_set_section ${row#h:}; return; fi
  [[ -n $LOCK[row] ]] && return
  PICK[row]=$(( ! PICK[row] ))
}

tui_toggle_section() {
  local r=$CUR
  while (( r > 1 )) && [[ $ROWS[r] != h:* ]]; do (( r-- )); done
  tui_set_section ${ROWS[r]#h:}
}

tui_move() {
  (( CUR += $1 ))
  (( CUR < 1 )) && CUR=1
  (( CUR > $#ROWS )) && CUR=$#ROWS
}

tui_draw() {
  local -a out targets
  local list_h=$(( TUI_H - 7 )) r row cat i mark label right hint pad w total=0 d1 d2 tag tagc e=
  (( CUR < TOP )) && TOP=$CUR
  (( CUR >= TOP + list_h )) && TOP=$(( CUR - list_h + 1 ))

  for (( i = 1; i <= $#I_CAT; i++ )); do
    (( PICK[i] )) || continue
    (( total += I_KB[i] ))
  done
  out+=(" ${BOLD}makkili${RESET}  ${DIM}$DISK_LINE${RESET}")
  label=" Selected ${BOLD}$(human $total)${RESET} ${DIM}of $FOUND_HUMAN found"
  out+=("$label$RESET" "")

  for (( r = TOP; r < TOP + list_h; r++ )); do
    (( r > $#ROWS )) && { out+=(""); continue }
    row=$ROWS[r]
    (( r == CUR )) && mark="${BOLD}❯${RESET} " || mark="  "
    if [[ $row == h:* ]]; then
      cat=${row#h:}
      section_state $cat
      right="$(human $SEC_SEL) of $(human $SEC_ALL)"
      label=${CATEGORY_NAME[$cat]} hint=${CATEGORY_HINT[$cat]}
      w=$(( TUI_W - 2 - 4 - ${#right} - 2 ))
      if (( ${#label} + 2 + ${#hint} <= w )); then
        printf -v pad '%*s' $(( w - ${#label} - 2 - ${#hint} )) ''
        out+=("$mark$SEC_BOX ${BOLD}$label${RESET}  ${DIM}$hint${RESET}$pad  ${BOLD}$right${RESET}")
      else
        fit $label $w
        out+=("$mark$SEC_BOX ${BOLD}${(r:w:)REPLY}${RESET}  ${BOLD}$right${RESET}")
      fi
    else
      i=$row
      item_tag $i; tag=$REPLY tagc=$REPLY2
      w=$(( TUI_W - 2 - 2 - 4 - 9 - 2 - (${#tag} ? ${#tag} + 2 : 0) - 1 ))
      fit $I_LABEL[i] $w
      label=${(r:w:)REPLY}
      (( r == CUR )) && label="${BOLD}$label${RESET}"
      if [[ -n $LOCK[i] ]]; then box="${DIM}[-]${RESET}"
      elif (( PICK[i] )); then box="${GREEN}[x]${RESET}"
      else box="[ ]"
      fi
      out+=("$mark  $box ${(l:9:)I_SIZE[i]}  $label${tag:+  $tagc$tag$RESET}")
    fi
  done

  row=$ROWS[CUR]
  if [[ $row == h:* ]]; then
    cat=${row#h:}
    d1="${CATEGORY_NAME[$cat]}: ${CATEGORY_HINT[$cat]}"
    d2="space or a toggles every item in this section"
  else
    d1=$I_NOTE[row]
    if [[ $I_KIND[row] == cmd ]]; then
      d2="runs: $I_TARGET[row]"
    else
      targets=(${(f)I_TARGET[row]})
      d2=${targets[1]/#$HOME/$TILDE}
      (( $#targets > 1 )) && d2+="  (+$(( $#targets - 1 )) more)"
    fi
  fi
  out+=("${DIM}${(l:TUI_W::─:)e}${RESET}")
  fit " $d1" $TUI_W; out+=("$REPLY")
  fit " $d2" $TUI_W; out+=("${DIM}$REPLY${RESET}")
  out+=("${DIM} ↑↓ move · space select · a section · enter continue · q quit${RESET}")
  print -n -- $'\e[H'"${(pj:\e[K\n:)out}"$'\e[K\e[J' >/dev/tty
}

# Interactive checklist over ROWS; returns non-zero when the user quits.
pick_items() {
  local key rest result=0
  local e=
  tui_size
  CUR=1 TOP=1
  disk_bar 20; DISK_LINE=$REPLY
  local all=0 i
  for (( i = 1; i <= $#I_KB; i++ )); do (( all += I_KB[i] )); done
  FOUND_HUMAN=$(human $all)
  print -n $'\e[?1049h\e[?25l' >/dev/tty
  trap 'tui_restore; exit 130' INT TERM
  trap 'tui_size' WINCH
  while true; do
    tui_draw
    read -sk1 key </dev/tty || continue
    case $key in
      $'\e')
        rest=
        read -sk2 -t 0.05 rest </dev/tty
        case $rest in
          '[A'|OA) tui_move -1 ;;
          '[B'|OB) tui_move 1 ;;
          '[5')    read -sk1 -t 0.05 e </dev/tty; tui_move $(( 7 - TUI_H )) ;;
          '[6')    read -sk1 -t 0.05 e </dev/tty; tui_move $(( TUI_H - 7 )) ;;
          '[H')    CUR=1 ;;
          '[F')    CUR=$#ROWS ;;
          '')      result=1; break ;;
        esac ;;
      k)           tui_move -1 ;;
      j)           tui_move 1 ;;
      g)           CUR=1 ;;
      G)           CUR=$#ROWS ;;
      ' ')         tui_toggle ;;
      a)           tui_toggle_section ;;
      $'\n'|$'\r') break ;;
      q|Q)         result=1; break ;;
    esac
  done
  tui_restore
  trap - INT TERM WINCH
  return $result
}
