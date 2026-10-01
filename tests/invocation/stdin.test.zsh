# claude-invocation and prompt-grammar: standard input and the "something to send" rule.

zt_load
source $ZT_TESTS/lib/pty.zsh

# @scenario claude-invocation: Piped input and prompt
test_piped_input_and_prompt() {
  zt_run_pipe $'diff --git a/x b/x\n+new line\n' zco haiku summarize for a changelog
  assert_status 0
  zt_claude_stdin_kind; assert_eq "$REPLY" pipe
  zt_claude_stdin; assert_eq "$REPLY" $'diff --git a/x b/x\n+new line\n'
  assert_argv_has -- 'summarize for a changelog'
}

# @scenario prompt-grammar: Piped input without a prompt
test_piped_input_without_a_prompt() {
  zt_run_pipe 'the diff' zco haiku
  assert_status 0
  zt_claude_stdin; assert_eq "$REPLY" 'the diff'
  assert_argv -p --model haiku --permission-mode auto --strict-mcp-config
}

# @scenario claude-invocation: Redirected file
test_redirected_file() {
  print -r -- 'meeting notes' > notes.txt
  zt_run_stdin notes.txt zco haiku summarize
  zt_claude_stdin_kind; assert_eq "$REPLY" file
  zt_claude_stdin; assert_eq "$REPLY" $'meeting notes\n'
}

test_here_string_and_process_substitution_count_as_input() {
  zt_run eval 'zco haiku <<< "from a here-string"'
  zt_claude_stdin; assert_eq "$REPLY" $'from a here-string\n'
  zt_run eval 'zco haiku < <(print -r -- from a process)'
  zt_claude_stdin; assert_eq "$REPLY" $'from a process\n'
}

test_character_device_stdin_is_replaced_by_dev_null() {
  zt_zco opus commit local changes
  zt_claude_stdin_kind; assert_eq "$REPLY" chardev
}

# @scenario claude-invocation: Interactive terminal
test_interactive_terminal() {
  zt_pty_start "source ${(q)ZT_PLUGIN}"
  zt_pty_run 'zco opus commit local changes'
  zt_pty_stop
  zt_claude_stdin_kind
  assert_eq "$REPLY" chardev "Claude Code must read /dev/null, not the terminal"
  assert_argv_has -- 'commit local changes'
}

# @scenario prompt-grammar: Nothing to send
test_nothing_to_send() {
  zt_pty_start "source ${(q)ZT_PLUGIN}"
  zt_pty_run 'zco opus xhigh; print -r -- "status=$?"'
  zt_pty_stop
  assert_contains "$ZT_PTY_OUT" 'status=2'
  assert_contains "$ZT_PTY_OUT" 'nothing to send'
  assert_not_run
}

test_nothing_to_send_without_a_terminal() {
  zt_zco opus xhigh
  assert_status 2
  assert_contains "$ZT_ERR" 'nothing to send'
  assert_not_run
  zt_zco opus -n --
  assert_status 2
}

test_skill_alone_is_enough() {
  zt_zco haiku -s prepare-commit
  assert_status 0
  assert_argv_has -- /prepare-commit
}
