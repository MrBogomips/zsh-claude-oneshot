# claude-invocation: which command runs Claude Code.

zt_load

# @scenario claude-invocation: Default command
test_default_command() {
  zt_zco opus commit local changes
  assert_status 0
  assert_eq "$(zt_claude_calls)" 1 "the external claude (the test double) runs"
  assert_eq "$ZT_OUT" 'fake answer'
}

test_an_alias_named_claude_does_not_hide_the_default_command() {
  alias claude='claude --bare'
  zt_zco opus x
  assert_status 0
  assert_argv_lacks --bare
}

# @scenario claude-invocation: Wrapper function
test_wrapper_function() {
  claude-work() { CLAUDE_WRAPPED=yes claude "$@" }
  export FAKE_CLAUDE_ENV=CLAUDE_WRAPPED
  ZCO_CLAUDE_CMD=claude-work zt_zco opus commit local changes
  assert_status 0
  zt_claude_env CLAUDE_WRAPPED
  assert_eq "$REPLY" yes "claude-work was called"
  assert_argv_has -p --model opus
}

# @scenario claude-invocation: Multi-word command with quoted value
test_multi_word_command_with_quoted_value() {
  ZCO_CLAUDE_CMD="env CLAUDE_CONFIG_DIR='/tmp/cfg dir' claude" zt_zco opus x
  assert_status 0
  zt_claude_env CLAUDE_CONFIG_DIR
  assert_eq "$REPLY" '/tmp/cfg dir'
}

test_array_command() {
  ZCO_CLAUDE_CMD=( env 'CLAUDE_CONFIG_DIR=/tmp/a b' claude )
  zt_zco opus x
  assert_status 0
  zt_claude_env CLAUDE_CONFIG_DIR
  assert_eq "$REPLY" '/tmp/a b'
}

# @scenario claude-invocation: No evaluation of the setting
test_no_evaluation_of_the_setting() {
  local target=$ZT_TMP/pwned
  ZCO_CLAUDE_CMD="claude \$(touch $target) \`touch $target\` ; touch $target" zt_zco opus x
  assert_file_absent $target
  assert_argv_has "\$(touch $target)" "\`touch $target\`" ';' touch $target -p
}

# @scenario claude-invocation: Command from the user file
test_command_from_the_user_file() {
  claude-work() { CLAUDE_WRAPPED=yes claude "$@" }
  export FAKE_CLAUDE_ENV=CLAUDE_WRAPPED
  zt_user_config 'claude_cmd = claude-work'
  zt_zco opus commit local changes
  assert_status 0
  zt_claude_env CLAUDE_WRAPPED
  assert_eq "$REPLY" yes
}

# @scenario claude-invocation: Command not found
test_command_not_found() {
  ZCO_CLAUDE_CMD=no-such-claude zt_zco opus x
  assert_status 127
  assert_contains "$ZT_ERR" no-such-claude
  assert_eq "$ZT_OUT" ''
  assert_not_run
}

test_command_path_not_executable() {
  ZCO_CLAUDE_CMD=$ZT_TMP/missing/claude zt_zco opus x
  assert_status 127
  assert_contains "$ZT_ERR" "$ZT_TMP/missing/claude"
}

# @scenario claude-invocation: Alias as command
test_alias_as_command() {
  alias claude-alias=claude
  ZCO_CLAUDE_CMD=claude-alias zt_zco opus x
  assert_ne $ZT_RC 0
  assert_contains "$ZT_ERR" claude-alias
  assert_contains "$ZT_ERR" function
  assert_not_run
}

test_empty_command_setting_means_the_default() {
  ZCO_CLAUDE_CMD= zt_zco opus x
  assert_status 0
  assert_eq "$(zt_claude_calls)" 1
}
