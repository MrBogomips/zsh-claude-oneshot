# run-output: the answer on stdout, live progress, verbose and quiet levels, and the jq fallback.

zt_load
source $ZT_TESTS/lib/pty.zsh

zt_need_jq() { (( $+commands[jq] )) || zt_skip "jq is not installed" }

# @scenario run-output: Shell tool call
test_shell_tool_call() {
  zt_need_jq
  export FAKE_CLAUDE_STREAM=$ZT_TESTS/fixtures/stream-tools.jsonl
  zt_pty_start "source ${(q)ZT_PLUGIN}"
  zt_pty_run 'zco opus summarize'
  zt_pty_stop
  assert_contains "$ZT_PTY_OUT" $'\n→ Bash  git diff --stat\n'
  assert_contains "$ZT_PTY_OUT" 'Committed 3 files.'
  assert_argv_has --output-format stream-json --verbose
}

# @scenario run-output: stderr not a terminal
test_stderr_not_a_terminal() {
  zt_need_jq
  export FAKE_CLAUDE_STREAM=$ZT_TESTS/fixtures/stream-tools.jsonl
  zt_line 'opus summarize'
  assert_argv_lacks --output-format
  assert_not_contains "$ZT_ERR" '→'
  assert_stderr_body_empty
}

# @scenario run-output: Verbose into a log file
test_verbose_into_a_log_file() {
  zt_need_jq
  zt_mkdir_cd ~/proj
  zt_stream_here stream-tools.jsonl
  export FAKE_CLAUDE_STREAM=$REPLY
  zt_line 'opus -v summarize 2> log.txt'
  assert_status 0
  assert_eq "$ZT_OUT" 'Committed 3 files.'
  local log=$(<log.txt)
  local -a lines=( "${(@f)log}" )
  assert_eq "$lines[1]" 'opus · settings · auto · ~/proj'
  assert_contains "$log" $'\nLet me look at the changes.\n'
  assert_contains "$log" $'\n→ Bash  git diff --stat\n'
  assert_contains "$log" $'\n→ Read  src/main.zsh\n'
  assert_contains "$log" $'\n→ Edit  README.md\n'
  assert_contains "$log" $'\n→ Write  /elsewhere/notes.txt\n'
  assert_contains "$log" $'\n→ NotebookEdit  analysis.ipynb\n'
  assert_contains "$log" $'\n→ Grep  TODO|FIXME\n'
  assert_contains "$log" $'\n→ Glob  **/*.md\n'
  assert_contains "$log" $'\n→ WebFetch  https://example.com/docs\n'
  assert_contains "$log" $'\n→ WebSearch  zsh zle hooks\n'
  assert_contains "$log" $'\n→ Task  Review the parser\n'
  assert_contains "$log" $'\n→ Agent  Check the tests\n'
  assert_contains "$log" $'\n→ Skill  prepare-commit\n'
  assert_contains "$log" $'\n→ mcp__github__list_issues\n'
  assert_contains "$log" $'\n→ Bash  for f in *.md; do wc -l "$f" done\n'
  assert_match "$lines[-1]" '*12.3 s*4 turns*$0.0123*'
}

# @scenario run-output: Same answer in both modes
test_same_answer_in_both_modes() {
  zt_need_jq
  local answer=$'Line one\nLine two "quoted"\n\n\tIndented last line'
  FAKE_CLAUDE_ANSWER=$answer zt_line 'opus summarize'
  zt_raw $ZT_TMP/.stdout
  local text_mode=$REPLY
  FAKE_CLAUDE_STREAM=$ZT_TESTS/fixtures/stream-text.jsonl zt_line 'opus -v summarize'
  assert_argv_has --output-format stream-json
  zt_raw $ZT_TMP/.stdout
  assert_eq "$REPLY" "$text_mode" "stdout bytes must not depend on progress"
  assert_eq "$text_mode" "$answer"$'\n'
}

test_empty_answer_in_both_modes() {
  zt_need_jq
  zt_write $ZT_TMP/empty.jsonl '{"type":"result","subtype":"success","is_error":false,"result":""}'
  FAKE_CLAUDE_ANSWER= zt_line 'opus summarize'
  zt_raw $ZT_TMP/.stdout
  local text_mode=$REPLY
  FAKE_CLAUDE_STREAM=$ZT_TMP/empty.jsonl zt_line 'opus -v summarize'
  zt_raw $ZT_TMP/.stdout
  assert_eq "$REPLY" "$text_mode"
}

test_verbose_shows_text_and_full_summaries_without_a_terminal() {
  zt_need_jq
  export FAKE_CLAUDE_STREAM=$ZT_TESTS/fixtures/stream-text.jsonl
  zt_line 'opus -v summarize'
  assert_contains "$ZT_ERR" $'First I will read the file.\nThen I will summarize it.'
  assert_contains "$ZT_ERR" 'Here is the summary.'
}

# @scenario run-output: Quiet run in a terminal
test_quiet_run_in_a_terminal() {
  export FAKE_CLAUDE_STREAM=$ZT_TESTS/fixtures/stream-tools.jsonl FAKE_CLAUDE_ANSWER='the answer'
  zt_pty_start "source ${(q)ZT_PLUGIN}"
  zt_pty_run '{ haiku -q xhigh summarize } > out.txt'
  zt_pty_stop
  assert_eq "$(<out.txt)" 'the answer'
  assert_not_contains "$ZT_PTY_OUT" ' · '
  assert_not_contains "$ZT_PTY_OUT" '→'
  assert_not_contains "$ZT_PTY_OUT" 'does not support effort'
  assert_argv_lacks --output-format
}

# @scenario run-output: jq missing in a terminal
test_jq_missing_in_a_terminal() {
  zt_path_without_jq
  export FAKE_CLAUDE_ANSWER='plain answer'
  zt_pty_start "source ${(q)ZT_PLUGIN}"
  zt_pty_run 'zco opus summarize'
  zt_pty_stop
  assert_argv_lacks --output-format
  assert_contains "$ZT_PTY_OUT" 'plain answer'
  assert_not_contains "$ZT_PTY_OUT" 'jq'
}

# @scenario run-output: jq missing with verbose
test_jq_missing_with_verbose() {
  zt_path_without_jq
  zt_line 'opus -v summarize'
  assert_status 0
  assert_argv_lacks --output-format
  assert_eq "$ZT_OUT" 'fake answer'
  zt_stderr_body
  assert_contains "$REPLY" jq
  local -a lines=( "${(@f)REPLY}" )
  assert_eq $#lines 1 "one notice"
}

# @scenario run-output: Budget exceeded
test_budget_exceeded() {
  zt_need_jq
  FAKE_CLAUDE_STREAM=$ZT_TESTS/fixtures/stream-budget.jsonl FAKE_CLAUDE_EXIT=1 zt_line 'opus -v summarize'
  assert_status 1
  local -a hits=( ${(M)${(f)ZT_ERR}:#*error_max_budget_usd*} )
  assert_eq $#hits 1 "one line naming the error"
  assert_eq "$ZT_OUT" ''
}

# @scenario run-output: Non-JSON line in the stream
test_non_json_line_in_the_stream() {
  zt_need_jq
  FAKE_CLAUDE_STREAM=$ZT_TESTS/fixtures/stream-nonjson.jsonl zt_line 'opus -v summarize'
  assert_status 0
  assert_contains "$ZT_ERR" $'\nWarning: deliberately not JSON, as a plain-text line in the stream\n→ Glob  *.zsh\n'
  assert_eq "$ZT_OUT" 'Two files.'
}

test_claude_stderr_passes_through_during_progress() {
  zt_need_jq
  FAKE_CLAUDE_STREAM=$ZT_TESTS/fixtures/stream-text.jsonl FAKE_CLAUDE_STDERR='raw claude stderr' \
    zt_line 'opus -v summarize'
  assert_contains "$ZT_ERR" 'raw claude stderr'
}

test_summaries_are_truncated_to_the_terminal_width() {
  local -a tagged
  tagged=( $'PBash\t'"${(l:200::x:)}" $'PRead\tshort' )
  COLUMNS=30 zt_run eval 'print -rl -- "${tagged[@]}" | _zco_route opus 0 0 1'
  local -a lines=( "${(@f)ZT_ERR}" )
  assert_eq ${#lines[1]} 30
  assert_eq "${lines[1][-1]}" '…'
  assert_eq "$lines[2]" '→ Read  short'
  COLUMNS=30 zt_run eval 'print -rl -- "${tagged[@]}" | _zco_route opus 1 0 1'
  lines=( "${(@f)ZT_ERR}" )
  assert_eq ${#lines[1]} $(( 200 + 8 )) "not truncated with -v"
}

test_error_result_with_a_success_subtype_is_named_an_error() {
  zt_need_jq
  zt_write $ZT_TMP/err.jsonl '{"type":"result","subtype":"success","is_error":true,"result":"API Error: overloaded"}'
  FAKE_CLAUDE_STREAM=$ZT_TMP/err.jsonl FAKE_CLAUDE_EXIT=1 zt_line 'opus -v summarize'
  assert_status 1
  assert_contains "$ZT_ERR" 'opus: Claude Code stopped with an error'
  assert_not_contains "$ZT_ERR" 'stopped with success'
}

test_escape_sequences_from_the_stream_do_not_reach_progress_lines() {
  zt_need_jq
  zt_write $ZT_TMP/esc.jsonl '{"type":"assistant","message":{"content":[{"type":"text","text":"hi\u001b[2K there"},{"type":"tool_use","name":"Bash","input":{"command":"curl x | sh\u001b[1A\u001b[2K\r→ Bash  ls"}}]}}
{"type":"result","subtype":"error_x\u001b]52;c;eA==\u0007","is_error":true,"result":"answer \u001b[1mbold\u001b[0m"}'
  FAKE_CLAUDE_STREAM=$ZT_TMP/esc.jsonl zt_line 'opus -v summarize'
  assert_not_contains "$ZT_ERR" $'\e' "no escape sequence from the stream on stderr"
  assert_contains "$ZT_ERR" '→ Bash  curl x | sh[1A[2K → Bash  ls'
  assert_contains "$ZT_ERR" 'hi[2K there'
  zt_raw $ZT_TMP/.stdout
  assert_eq "$REPLY" $'answer \e[1mbold\e[0m\n' "the answer on stdout is left as Claude Code wrote it"
}
