# The zpty driver (tests/lib/pty.zsh).

source $ZT_TESTS/lib/pty.zsh

test_typed_line_output_is_returned() {
  zt_pty_start
  zt_pty_run 'print -r -- ok'
  assert_eq "${ZT_PTY_OUT%$'\n'}" ok
  zt_pty_stop
}

test_shell_is_interactive_with_a_terminal() {
  zt_pty_start
  zt_pty_run '[[ -o interactive && -t 0 && -t 2 ]] && print -r -- tty-ok'
  assert_contains "$ZT_PTY_OUT" tty-ok
  zt_pty_run 'print -r -- $HOME'
  assert_contains "$ZT_PTY_OUT" "$HOME"
  zt_pty_stop
}
