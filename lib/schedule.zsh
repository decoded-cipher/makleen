# makleen: the weekly report (launchd) and its notification. Sourced by the makleen entry script.

cmd_schedule() {
  case $1 in
    install)
      mkdir -p ${AGENT_PLIST:h}
      cat > $AGENT_PLIST <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/zsh</string><string>$SCRIPT</string><string>notify</string></array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>$PATH</string></dict>
  <key>StartCalendarInterval</key>
  <dict><key>Weekday</key><integer>0</integer><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
</dict>
</plist>
EOF
      launchctl bootout gui/$UID/$AGENT_LABEL 2>/dev/null
      launchctl bootstrap gui/$UID $AGENT_PLIST &&
        say "Weekly report scheduled for Sundays 10:00. It only reports; nothing is deleted. Reports: ${LOG_DIR/#$HOME/$TILDE}/<date>_report.log"
      ;;
    remove)
      launchctl bootout gui/$UID/$AGENT_LABEL 2>/dev/null
      rm -f $AGENT_PLIST && say "Weekly report removed."
      ;;
    *) die "usage: makleen schedule install|remove" ;;
  esac
}

cmd_notify() {
  CATS=($ALL_CATEGORIES)
  log_open report
  exec 2>>$LOG_FILE  # launchd discards output, so errors go into this run's log
  collect_all
  print_report >> $LOG_FILE
  local picked=0 i
  for (( i = 1; i <= $#I_KB; i++ )); do (( PICK[i] )) && (( picked += I_KB[i] )); done
  local msg="$(human $picked) can be reclaimed. Run makleen to review."
  local q=$(kb_of $QUARANTINE_DIR)
  (( q )) && msg+=" Quarantine holds $(human $q)."
  osascript -e "display notification \"$msg\" with title \"makleen\""
}
