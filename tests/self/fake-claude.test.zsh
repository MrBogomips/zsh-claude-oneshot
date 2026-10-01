# The Claude Code test double (tests/bin/claude).

test_records_arguments_exactly() {
  zt_run claude -p 'two words' $'line one\nline two' '' --end
  assert_status 0
  assert_argv -p 'two words' $'line one\nline two' '' --end
  assert_eq "$(zt_claude_calls)" 1
}

test_tells_stdin_kinds_apart() {
  print -r -- data > $ZT_TMP/in.txt

  zt_run claude x
  zt_claude_stdin_kind; assert_eq "$REPLY" chardev
  zt_claude_stdin; assert_eq "$REPLY" ''

  zt_run_pipe $'piped\n' claude x
  zt_claude_stdin_kind; assert_eq "$REPLY" pipe
  zt_claude_stdin; assert_eq "$REPLY" $'piped\n'

  zt_run_stdin $ZT_TMP/in.txt claude x
  zt_claude_stdin_kind; assert_eq "$REPLY" file
  zt_claude_stdin; assert_eq "$REPLY" $'data\n'

  assert_eq "$(zt_claude_calls)" 3
}

test_answer_stderr_and_exit_status() {
  FAKE_CLAUDE_ANSWER='hello there' FAKE_CLAUDE_STDERR='a warning' FAKE_CLAUDE_EXIT=3 zt_run claude -p x
  assert_status 3
  assert_eq "$ZT_OUT" 'hello there'
  assert_eq "$ZT_ERR" 'a warning'
}

test_stream_json_replay() {
  zt_write $ZT_TMP/stream.jsonl '{"type":"result","result":"from file"}'
  FAKE_CLAUDE_STREAM=$ZT_TMP/stream.jsonl zt_run claude -p --output-format stream-json --verbose x
  assert_eq "$ZT_OUT" '{"type":"result","result":"from file"}'

  FAKE_CLAUDE_ANSWER=$'two\nlines "quoted"' zt_run claude -p --output-format stream-json --verbose x
  assert_contains "$ZT_OUT" '"result":"two\nlines \"quoted\""'
}

test_records_selected_environment() {
  CLAUDE_CONFIG_DIR='/tmp/cfg dir' FAKE_CLAUDE_ENV=MY_VAR MY_VAR=42 zt_run claude x
  zt_claude_env CLAUDE_CONFIG_DIR; assert_eq "$REPLY" '/tmp/cfg dir'
  zt_claude_env MY_VAR; assert_eq "$REPLY" 42
  assert_true "unset variables are not recorded" eval '! zt_claude_env ANTHROPIC_DEFAULT_OPUS_MODEL'
}
