# model-commands: the zco entry point.

zt_load

# @scenario model-commands: Model without a command
test_model_without_a_command() {
  zt_line "zco 'opus[1m]' summarize this repo"
  assert_status 0
  assert_argv -p --model 'opus[1m]' --permission-mode auto --strict-mcp-config -- 'summarize this repo'
}

# @scenario model-commands: Redirecting output
test_redirecting_output() {
  FAKE_CLAUDE_ANSWER='the release notes' zt_line "zco opus 'write release notes' > notes.md"
  assert_status 0
  assert_eq "$(<notes.md)" 'the release notes'
  assert_eq "$ZT_OUT" ''
  assert_argv_has -- 'write release notes'
}

# @scenario model-commands: Missing model
test_missing_model() {
  zt_zco
  assert_status 2
  assert_match "$ZT_ERR" 'zco: *'
  assert_contains "$ZT_ERR" 'usage: zco <model>'
  assert_not_run
}

test_model_starting_with_a_dash() {
  zt_zco -n commit
  assert_status 2
  assert_not_run
  zt_zco -h
  assert_status 2
}

test_zco_follows_normal_globbing() {
  touch one.md two.md
  zt_line 'zco opus list *.md'
  assert_argv_has -- 'list one.md two.md'
}

test_zco_help_names_the_model() {
  zt_zco sonnet -h
  assert_status 0
  assert_contains "$ZT_OUT" 'usage: zco <model>'
  assert_contains "$ZT_OUT" 'model sonnet'
}
