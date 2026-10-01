# claude-invocation: the exact arguments, permission mode, effort, MCP, sessions, budget, exit status.
# stderr is a file here, so it is never a terminal.

zt_load

# @scenario claude-invocation: Defaults with stderr not a terminal
test_defaults_with_stderr_not_a_terminal() {
  zt_zco opus commit local changes
  assert_status 0
  assert_argv -p --model opus --permission-mode auto --strict-mcp-config -- 'commit local changes'
}

# @scenario claude-invocation: Everything turned on
test_everything_turned_on() {
  (( $+commands[jq] )) || zt_skip "jq is not installed"
  ZCO_SESSION_PERSISTENCE=0 ZCO_MAX_BUDGET_USD=0.50 zt_zco opus -v -m -c xhigh go ahead
  assert_argv -p --model opus --permission-mode auto --effort xhigh --continue \
    --no-session-persistence --max-budget-usd 0.50 --output-format stream-json --verbose -- 'go ahead'
}

# @scenario claude-invocation: Options from files and command line in order
test_options_from_files_and_command_line_in_order() {
  zt_write ~/proj/.zco.config $'agent = reviewer\nadd_dir = lib'
  cd ~/proj
  zt_zco opus --append-system-prompt 'Be terse.' --max-turns 5 summarize
  assert_status 0
  assert_argv -p --model opus --permission-mode auto --agent reviewer --append-system-prompt 'Be terse.' \
    --add-dir $HOME/proj/lib --strict-mcp-config --max-turns 5 -- summarize
}

test_every_position_in_order() {
  print -r -- 'be brief' > ~/append.md
  zt_user_config $'extra_args = --name\nextra_args = nightly\nmcp_config = ~/m.json\nsettings = ~/s.json\nsession_persistence = no\nmax_budget_usd = 1'
  zt_zco opus -e high -a rev --system-prompt SYS --append-system-prompt-file ~/append.md \
    --add-dir d1 --add-dir d2 --allowed-tools A1 --disallowed-tools D1 --fallback-model sonnet \
    --max-turns 3 -r ID -s skill go
  assert_status 0
  assert_argv -p --model opus --permission-mode auto --effort high --agent rev --system-prompt SYS \
    --append-system-prompt-file $HOME/append.md --add-dir d1 --add-dir d2 --allowed-tools A1 \
    --disallowed-tools D1 --settings $HOME/s.json --mcp-config $HOME/m.json --strict-mcp-config \
    --fallback-model sonnet --max-turns 3 --resume ID --no-session-persistence --max-budget-usd 1 \
    --name nightly -- '/skill go'
}

# @scenario claude-invocation: Model remapping left to Claude Code
test_model_remapping_left_to_claude_code() {
  ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-x zt_zco opus summarize
  assert_argv_has --model opus
  zt_claude_env ANTHROPIC_DEFAULT_OPUS_MODEL
  assert_eq "$REPLY" claude-opus-x
}

test_model_name_passed_as_given() {
  zt_zco 'opus[1m]' summarize this repo
  assert_argv_has --model 'opus[1m]'
}

# ------------------------------------------------------------------ permission mode

# @scenario claude-invocation: Default mode
test_default_mode() {
  zt_zco opus commit local changes
  assert_argv_has --permission-mode auto
}

# @scenario claude-invocation: Configured mode
test_configured_mode() {
  ZCO_PERMISSION_MODE=acceptEdits zt_zco sonnet edit README.md: add an install section
  assert_argv_has --permission-mode acceptEdits
  assert_argv_has -- 'edit README.md: add an install section'
}

# @scenario claude-invocation: Dry run wins
test_dry_run_wins() {
  ZCO_PERMISSION_MODE=acceptEdits zt_zco haiku -n reorg this folder by year
  assert_argv_has --permission-mode plan
}

test_unknown_mode_is_passed_through() {
  zt_zco opus --permission-mode someFutureMode x
  assert_argv_has --permission-mode someFutureMode
}

test_empty_mode_means_the_default() {
  zt_user_config 'permission_mode ='
  zt_zco opus x
  assert_argv_has --permission-mode auto
}

# ------------------------------------------------------------------ effort

# @scenario claude-invocation: No effort anywhere
test_no_effort_anywhere() {
  zt_zco opus summarize
  assert_argv_lacks --effort
}

# @scenario claude-invocation: Model-specific variable beats the global one
test_model_specific_variable_beats_the_global_one() {
  export ZCO_EFFORT=low ZCO_EFFORT_OPUS=max
  zt_zco opus summarize
  assert_argv_has --effort max
  zt_zco sonnet summarize
  assert_argv_has --effort low
}

# @scenario claude-invocation: Command line beats variables
test_command_line_beats_variables() {
  ZCO_EFFORT_OPUS=max zt_zco opus medium summarize
  assert_argv_has --effort medium
}

# @scenario claude-invocation: Invalid variable value
test_invalid_variable_value() {
  ZCO_EFFORT=turbo zt_zco opus summarize
  assert_status 2
  assert_contains "$ZT_ERR" ZCO_EFFORT
  assert_not_run
}

# @scenario claude-invocation: Effort word with haiku
test_effort_word_with_haiku() {
  zt_zco haiku xhigh summarize
  assert_status 0
  assert_argv_lacks --effort
  zt_stderr_body
  assert_contains "$REPLY" 'haiku does not support effort'
  local -a lines=( "${(@f)REPLY}" )
  assert_eq $#lines 1 "exactly one notice line"
}

# @scenario claude-invocation: Global effort with haiku
test_global_effort_with_haiku() {
  ZCO_EFFORT=high zt_zco haiku summarize
  assert_argv_lacks --effort
  assert_stderr_body_empty "no notice for ZCO_EFFORT"
  zt_user_config 'effort = high'
  zt_zco haiku summarize
  assert_argv_lacks --effort
  assert_stderr_body_empty "no notice for a file entry outside sections"
}

# @scenario claude-invocation: Haiku section with effort
test_haiku_section_with_effort() {
  zt_user_config $'[haiku]\neffort = low'
  zt_zco haiku summarize
  assert_argv_lacks --effort
  zt_stderr_body
  assert_contains "$REPLY" '~/.zco.config:2'
  local -a lines=( "${(@f)REPLY}" )
  assert_eq $#lines 1 "exactly one notice line"
}

test_haiku_model_specific_variable_and_quiet() {
  ZCO_EFFORT_CLAUDE_HAIKU_4_5=low zt_zco claude-haiku-4-5 summarize
  assert_argv_lacks --effort
  zt_stderr_body
  assert_contains "$REPLY" ZCO_EFFORT_CLAUDE_HAIKU_4_5
  zt_zco Haiku -q xhigh summarize
  assert_argv_lacks --effort
  assert_eq "$ZT_ERR" '' "-q silences the notice"
}

# ------------------------------------------------------------------ MCP, continue, sessions, budget

# @scenario claude-invocation: MCP requested
test_mcp_requested() {
  zt_zco opus -m check the open issues
  assert_argv_lacks --strict-mcp-config
}

# @scenario claude-invocation: MCP enabled by variable
test_mcp_enabled_by_variable() {
  ZCO_MCP=1 zt_zco opus check the open issues
  assert_argv_lacks --strict-mcp-config
}

# @scenario claude-invocation: Follow-up after a dry run
test_follow_up_after_a_dry_run() {
  zt_zco haiku -n reorg this folder by year
  assert_argv_has --permission-mode plan
  zt_zco haiku -c go ahead
  assert_argv -p --model haiku --permission-mode auto --strict-mcp-config --continue -- 'go ahead'
}

# @scenario claude-invocation: Persistence turned off
test_persistence_turned_off() {
  ZCO_SESSION_PERSISTENCE=false zt_zco opus summarize
  assert_argv_has --no-session-persistence
}

# @scenario claude-invocation: Persistence turned off in the user file
test_persistence_turned_off_in_the_user_file() {
  zt_user_config 'session_persistence = off'
  zt_zco opus summarize
  assert_argv_has --no-session-persistence
}

test_persistence_on_by_default() {
  zt_zco opus summarize
  assert_argv_lacks --no-session-persistence
}

# @scenario claude-invocation: Budget set
test_budget_set() {
  ZCO_MAX_BUDGET_USD=0.25 zt_zco opus summarize
  assert_argv_has --max-budget-usd 0.25
}

# @scenario claude-invocation: Invalid budget
test_invalid_budget() {
  ZCO_MAX_BUDGET_USD=cheap zt_zco opus summarize
  assert_status 2
  assert_contains "$ZT_ERR" ZCO_MAX_BUDGET_USD
  assert_not_run
}

# ------------------------------------------------------------------ exit status

# @scenario claude-invocation: Failing run
test_failing_run() {
  FAKE_CLAUDE_EXIT=3 zt_zco opus summarize
  assert_status 3
}

test_answer_and_claude_stderr_pass_through() {
  FAKE_CLAUDE_ANSWER=$'line one\nline two' FAKE_CLAUDE_STDERR='claude warning' zt_zco opus summarize
  assert_eq "$ZT_OUT" $'line one\nline two'
  assert_contains "$ZT_ERR" 'claude warning'
}

# @scenario claude-invocation: Failing run with live progress
test_failing_run_with_live_progress() {
  (( $+commands[jq] )) || zt_skip "jq is not installed"
  FAKE_CLAUDE_EXIT=1 zt_zco opus -v summarize
  assert_argv_has --output-format stream-json --verbose
  assert_status 1
}
