# raw-line-capture: coexistence with other line-editor plugins, in either load order.
# zsh-syntax-highlighting and zsh-autosuggestions come from tests/.deps/ (zsh tests/fetch-deps.zsh);
# without them those tests are skipped with a notice.

source $ZT_TESTS/lib/pty.zsh

ZT_DEPS=${ZT_DEPS_DIR:-$ZT_TESTS/.deps}   # ZT_DEPS_DIR: for the self-test of the skip

assert_prompt() {
  zt_claude_argv || zt_fail "Claude Code was not run" "  terminal: ${(qqqq)ZT_PTY_OUT}"
  assert_eq "${reply[-1]}" "$1" "prompt received by Claude Code"
}

zt_need_deps() {
  [[ -r $ZT_DEPS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh &&
     -r $ZT_DEPS/zsh-autosuggestions/zsh-autosuggestions.zsh ]] ||
    zt_skip "tests/.deps/ is absent: run zsh tests/fetch-deps.zsh to test with zsh-syntax-highlighting and zsh-autosuggestions"
}

# A widget on Ctrl-X Ctrl-P that records what the other plugins put on the line editor.
# zsh-autosuggestions clears the suggestion before any widget it wraps, so the probe is excluded.
zt_probe_widget() {
  REPLY="zt-probe() { print -r -- \"suggestion=[\$POSTDISPLAY] highlights=\${#region_highlight}\" > ${(q)ZT_TMP}/probe }; zle -N zt-probe; bindkey '^X^P' zt-probe; ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(zt-probe)"
}

# Type a prefix of an earlier command, probe, then clear the line.
# Both plugins skip their work while more input is pending, so the prefix is typed once zle is
# reading, the probe waits until zle has drawn it, and it probes again until the suggestion,
# which is fetched asynchronously, shows (or 5 seconds pass).
zt_probe_line_editor() {
  zt_pty_run 'print -r -- hello-world'
  zt_pty_wait 5 '<ZT-PROMPT>' || zt_fail "no prompt drawn"
  zt_pty_send 'print -r -- hel'
  zt_pty_wait 5 ' -- hel' || zt_fail "the typed prefix was not drawn"
  local -F deadline=$(( EPOCHREALTIME + 5 ))
  while (( EPOCHREALTIME < deadline )); do
    zselect -t 50                  # leave the asynchronous fetch alone for a moment
    zt_pty_send $'\x18\x10'
    zselect -t 10
    [[ -s $ZT_TMP/probe && $(<$ZT_TMP/probe) != *'suggestion=[]'* ]] && break
  done
  zt_pty_keys $'\x15\r'          # Ctrl-U clears the line, Enter gives a new prompt
}

# @scenario raw-line-capture: Loaded after an existing zle-line-finish widget
test_loaded_after_an_existing_zle_line_finish_widget() {
  zt_pty_start 'bindkey -e' \
    "omz_finish() { print -r -- finish >> ${(q)ZT_TMP}/finish.log }" \
    'zle -N zle-line-finish omz_finish' \
    "source ${(q)ZT_PLUGIN}"
  zt_pty_run "opus don't touch tests"
  zt_pty_run 'true'
  zt_pty_stop
  assert_prompt "don't touch tests"
  local -a ran=( "${(@f)$(<$ZT_TMP/finish.log)}" )
  assert_eq $#ran 2 "the existing widget runs on every accepted line"
}

zt_coexist() {   # order: before or after
  zt_need_deps
  local -a plugins=(
    "source ${(q)ZT_DEPS}/zsh-autosuggestions/zsh-autosuggestions.zsh"
    "source ${(q)ZT_DEPS}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  )
  zt_probe_widget
  local probe_widget=$REPLY baseline probe

  # Baseline: what the two plugins do on this zsh without zsh-claude-oneshot. (On zsh 5.3,
  # for example, zsh-autosuggestions shows no suggestion next to zsh-syntax-highlighting.)
  zt_pty_start 'bindkey -e' "$probe_widget" "${plugins[@]}"
  zt_probe_line_editor
  zt_pty_stop
  baseline=$(<$ZT_TMP/probe)
  rm -f -- $ZT_TMP/probe $ZT_TMP/history

  if [[ $1 == before ]]; then
    zt_pty_start 'bindkey -e' "$probe_widget" "${plugins[@]}" "source ${(q)ZT_PLUGIN}"
  else
    zt_pty_start 'bindkey -e' "$probe_widget" "source ${(q)ZT_PLUGIN}" "${plugins[@]}"
  fi
  zt_pty_run "opus don't touch tests > seriously"
  zt_pty_run "sonnet a; b | c"
  zt_probe_line_editor
  zt_pty_stop
  assert_eq "$(zt_claude_calls)" 2
  assert_prompt 'a; b | c'
  zt_claude_argv 1
  assert_eq "${reply[-1]}" "don't touch tests > seriously" "first prompt intact"
  assert_file_absent seriously

  probe=$(<$ZT_TMP/probe)
  assert_eq "${probe%% *}" "${baseline%% *}" "zsh-autosuggestions suggests as it does without zsh-claude-oneshot"
  if [[ $baseline == *'highlights=0' ]]; then
    assert_match "$probe" '*highlights=0'
  else
    assert_not_contains "$probe" 'highlights=0' "zsh-syntax-highlighting still highlights"
  fi
  if [[ $ZSH_VERSION == 5.<9->* || $ZSH_VERSION == <6->* ]]; then
    assert_eq "${baseline%% *}" 'suggestion=[lo-world]' "on this zsh the baseline must show the suggestion"
  fi
}

# @scenario raw-line-capture: Loaded before and after zsh-syntax-highlighting
test_loaded_after_zsh_syntax_highlighting_and_autosuggestions() {
  zt_coexist before
}

# @scenario raw-line-capture: Loaded before and after zsh-syntax-highlighting
test_loaded_before_zsh_syntax_highlighting_and_autosuggestions() {
  zt_coexist after
}
