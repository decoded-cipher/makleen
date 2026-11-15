# makleen: what AI coding agents leave behind. Sourced by the makleen entry script.

AGENT_WORKTREES=('*/.claude/worktrees/*' '~/.codex/worktrees/*' '~/.cursor/worktrees/*' '~/conductor/workspaces/*')
TEMP_DIRS=('/private/tmp/*' '/tmp/*' '/private/var/folders/*' '/var/folders/*')
typeset -a AGENT_WT CLAUDE_TMP_GONE

agent_idle() {  # path... -> REPLY days idle
  local f x t=0
  for f in "$@"; do [[ -e $f ]] && { x=$(zstat +mtime $f); (( x > t )) && t=$x }; done
  REPLY=$(( (EPOCHSECONDS - t) / 86400 ))
  (( REPLY >= AGENT_IDLE_DAYS ))
}

agent_tool() {  # worktree -> REPLY
  case $1 in
    */.claude/worktrees/*) REPLY="Claude Code" ;;
    $HOME/.codex/*)        REPLY=Codex ;;
    $HOME/.cursor/*)       REPLY=Cursor ;;
    *)                     REPLY=Conductor ;;
  esac
}

agent_claude_temp() {
  [[ -d $CLAUDE_TMP && -d $HOME/.claude/sessions ]] || return
  local f s d
  local -a live old
  for f in $HOME/.claude/sessions/*.json; do
    s=$(<$f)
    [[ $s =~ '"pid": *([0-9]+)' ]] && kill -0 $match[1] 2>/dev/null || continue
    [[ $s =~ '"sessionId": *"([^"]+)"' ]] && live+=($match[1])
  done
  for d in $CLAUDE_TMP/*/*(/); do
    [[ ${d:t} =~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' ]] && (( ! ${live[(Ie)${d:t}]} )) || continue
    agent_idle $d $d/* && ! untouchable $d && old+=($d)
  done
  (( $#old )) || return
  local kb=$(kb_of $old)
  (( kb >= 10240 )) || return
  CLAUDE_TMP_GONE=($old)
  add_item agents "Claude Code temp files of ended sessions (${#old})" $kb rm "${(F)old}" \
    "scratchpads, task output and pasted images; transcripts stay in ~/.claude"
}

worktree_safe() {  # worktree
  local out
  out=$(git -C $1 --no-optional-locks status --porcelain 2>/dev/null) && [[ -z $out ]] || return 1
  git -C $1 symbolic-ref -q HEAD >/dev/null && return 0
  [[ -n $(git -C $1 for-each-ref --contains HEAD --count=1 --format=x refs/heads refs/remotes refs/tags 2>/dev/null) ]]
}

agent_worktrees() {
  local root f e wt main b age kept=0 n=0
  local -a entries cmds names
  local -A seen stale blocked
  (( $#PROJECT_ROOTS )) || detect_project_roots
  for root in $PROJECT_ROOTS; do entries+=($root{,/*,/*/*,/*/*/*}/.git/worktrees/*(/)); done
  for f in $HOME/{.codex/worktrees,.cursor/worktrees,conductor/workspaces}/*{,/*}/.git(.); do
    e=$(<$f); e=${e#gitdir: }
    [[ $e == /* ]] || e=${f:h}/$e
    entries+=(${e:a})
  done
  for e in $entries; do
    [[ -z ${seen[$e]} && -r $e/gitdir && ${e:h:h:t} == .git ]] || continue
    seen[$e]=1
    wt=$(<$e/gitdir)
    [[ $wt == /* ]] || wt=$e/$wt
    wt=${wt:a:h} main=${e:h:h:h}
    if [[ ! -e $wt ]] || inside $wt $CLAUDE_TMP_GONE; then
      if path_matches $wt $AGENT_WORKTREES $TEMP_DIRS && ! untouchable $wt; then (( stale[$main]++ )); else blocked[$main]=1; fi
      continue
    fi
    path_matches $wt $AGENT_WORKTREES && ! untouchable $wt && [[ ! -e $e/locked ]] || continue
    agent_idle $e/HEAD $e/index $e/logs/HEAD || continue
    age=$REPLY
    worktree_safe $wt || { (( kept++ )); continue }
    b=$(git -C $wt symbolic-ref -q --short HEAD)
    agent_tool $wt
    AGENT_WT+=($wt)
    add_item agents "$REPLY worktree ${main:t}/${wt:t}" $(kb_of $wt) cmd "git -C ${(q)main} worktree remove ${(q)wt}" \
      "${b:+branch $b stays · }no uncommitted work · untouched ${age}d"
  done
  (( kept )) && skip agents "kept $kept idle agent worktree(s) with uncommitted work or commits on no branch"
  for main in ${(k)stale}; do
    [[ -n ${blocked[$main]} ]] && continue
    cmds+=("git -C ${(q)main} worktree prune") names+=(${main:t})
    (( n += stale[$main] ))
  done
  (( n )) && add_item agents "Stale git worktree entries ($n)" 0 cmd "${(j:; :)cmds}" \
    "worktree folders already gone · tidies ${(j:, :)${(@o)names}}"
}

agent_clones() {
  local d
  local -a old
  for d in $HOME/.codex/.tmp/plugins-clone-*(/) $HOME/.claude/plugins/cache/temp_git_*(/); do
    agent_idle $d && ! untouchable $d && old+=($d)
  done
  (( $#old )) || return
  local kb=$(kb_of $old)
  (( kb >= 10240 )) && add_item agents "Unfinished plugin downloads" $kb rm "${(F)old}" \
    "temporary clones from interrupted Claude Code or Codex plugin updates"
}

collect_agents() {
  progress "Looking at what AI agents left behind…"
  agent_claude_temp
  agent_worktrees
  agent_clones
}
