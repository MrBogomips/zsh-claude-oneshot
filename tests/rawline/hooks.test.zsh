# raw-line-capture: the default line mode at load time, and the hook staying installed.

source $ZT_TESTS/lib/pty.zsh

zt_rl_shell() {   # zshrc lines after loading the plugin...
  zt_pty_start 'bindkey -e' "source ${(q)ZT_PLUGIN}" "$@"
}

assert_prompt() {
  zt_claude_argv || zt_fail "Claude Code was not run" "  terminal: ${(qqqq)ZT_PTY_OUT}"
  assert_eq "${reply[-1]}" "$1" "prompt received by Claude Code"
}

test_invalid_raw_line_variable_warns_once_at_load() {
  ZCO_RAW_LINE=sometimes zt_run source $ZT_PLUGIN
  local -a lines=( "${(@f)ZT_ERR}" )
  assert_eq $#lines 1
  assert_contains "$ZT_ERR" ZCO_RAW_LINE
  _zco_raw_mode; assert_eq "$REPLY" literal
}

test_invalid_raw_line_in_the_user_file_warns_with_file_and_line() {
  zt_user_config $'effort = low\nraw_line = maybe'
  zt_run source $ZT_PLUGIN
  assert_contains "$ZT_ERR" '~/.zco.config:2'
  _zco_raw_mode; assert_eq "$REPLY" literal
}

test_raw_line_values() {
  zt_functions
  local v
  for v in literal LITERAL on 1 true yes; do _zco_raw_mode $v; assert_eq "$REPLY" literal "$v"; done
  for v in off 0 false No; do _zco_raw_mode $v; assert_eq "$REPLY" off "$v"; done
  _zco_raw_mode shell; assert_eq "$REPLY" shell
  assert_true "invalid values return 1" eval '! _zco_raw_mode bogus'
}

test_invalid_default_means_literal_on_typed_lines() {
  zt_rl_shell 'ZCO_RAW_LINE=bogus'
  zt_pty_run "opus don't > seriously"
  zt_pty_stop
  assert_prompt "don't > seriously"
  assert_file_absent seriously
}

test_vared_input_is_not_rewritten() {
  zt_rl_shell
  zt_pty_keys 'x=; vared -p "<VARED>" x'$'\r' '<VARED>'
  zt_pty_run "opus don't"
  zt_pty_run 'print -r -- "x=[$x]"'
  zt_pty_stop
  assert_contains "$ZT_PTY_OUT" "x=[opus don't]"
  assert_not_run
}

# @scenario raw-line-capture: Widget replaced later
test_widget_replaced_later() {
  zt_rl_shell "my_finish() { print -r -- ran >> ${(q)ZT_TMP}/finish.log }"
  zt_pty_run 'zle -N zle-line-finish my_finish'     # another plugin replaces the widget
  zt_pty_run 'true'                                  # this line runs without the rewrite
  zt_pty_run "opus don't touch tests"
  zt_pty_run "opus again, don't"
  zt_pty_stop
  assert_prompt "again, don't"
  assert_eq "$(zt_claude_calls)" 2
  local -a ran=( "${(@f)$(<$ZT_TMP/finish.log)}" )
  assert_eq $#ran 3 "the replacing widget still runs on every line (true and both opus lines)"
}

test_replaced_widget_that_wraps_ours_triggers_no_reregistration() {
  zt_rl_shell \
    'zle -A zle-line-finish zt-orig-finish' \
    "zt_wrap() { print -r -- wrapped >> ${(q)ZT_TMP}/wrap.log; zle zt-orig-finish }" \
    'zle -N zle-line-finish zt_wrap'
  zt_pty_run "opus don't touch"
  zt_pty_run "opus don't touch either"
  zt_pty_run 'zstyle -g w zle-line-finish widgets; print -r -- "hooks=${(M)#w:#*_zco_line_finish}"'
  zt_pty_stop
  assert_prompt "don't touch either"
  assert_contains "$ZT_PTY_OUT" 'hooks=1'
}
