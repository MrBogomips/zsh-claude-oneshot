# Configuration and prompt-grammar scenarios run end to end through zco: what Claude Code
# receives, the exit status, and whether it runs at all.

zt_load

# ------------------------------------------------------------------ configuration

# @scenario configuration: No configuration files
test_no_configuration_files_run() {
  zt_zco opus summarize
  assert_status 0
  assert_stderr_body_empty "no warning without configuration files"
  assert_argv -p --model opus --permission-mode auto --strict-mcp-config -- summarize
}

# @scenario configuration: Scalar key through the environment
test_scalar_key_through_the_environment_run() {
  ZCO_AGENT=reviewer zt_zco opus summarize
  assert_argv_has --agent reviewer
}

# @scenario configuration: Environment beats files
test_environment_beats_files_run() {
  zt_write ~/proj/.zco.config 'permission_mode = acceptEdits'
  cd ~/proj
  ZCO_PERMISSION_MODE=plan zt_zco opus summarize
  assert_argv_has --permission-mode plan
}

# @scenario configuration: Command line beats everything
test_command_line_beats_everything_run() {
  zt_user_config $'effort = low\n[opus]\neffort = medium'
  zt_write ~/proj/.zco.config $'effort = high\n[opus]\neffort = xhigh'
  cd ~/proj
  ZCO_EFFORT=low ZCO_EFFORT_OPUS=medium zt_zco opus max summarize
  assert_argv_has --effort max
}

# @scenario configuration: Sections apply per model
test_sections_apply_per_model_run() {
  zt_user_config $'effort = medium\n[opus]\neffort = xhigh'
  zt_zco opus summarize
  assert_argv_has --effort xhigh
  zt_zco sonnet summarize
  assert_argv_has --effort medium
}

# @scenario configuration: Unknown key
test_unknown_key_run() {
  zt_user_config $'effort = low\n\nefort = high'
  zt_zco opus summarize
  assert_status 2
  assert_contains "$ZT_ERR" '~/.zco.config:3'
  assert_contains "$ZT_ERR" efort
  assert_not_run
}

# @scenario configuration: Project file sets the Claude command
test_project_file_sets_the_claude_command_run() {
  zt_write ~/clone/run-me.sh "#!/bin/sh
: > ${(q)ZT_TMP}/ran"
  chmod +x ~/clone/run-me.sh
  zt_write ~/clone/.zco.config 'claude_cmd = ./run-me.sh'
  cd ~/clone
  zt_zco opus summarize
  assert_status 2
  assert_contains "$ZT_ERR" 'claude_cmd is only allowed in the user file'
  assert_file_absent $ZT_TMP/ran
  assert_not_run
}

# @scenario configuration: Editing a file between runs
test_editing_a_file_between_runs_run() {
  zt_write ~/proj/.zco.config 'agent = reviewer'
  cd ~/proj
  zt_zco opus summarize
  assert_argv_lacks --effort
  print -r -- 'effort = high' >> .zco.config
  zt_zco opus summarize
  assert_argv_has --effort high
}

# @scenario configuration: Show where the effort comes from
test_show_config_through_the_command() {
  zt_user_config $'agent = reviewer\n\n[opus]\neffort = xhigh'
  zt_zco opus --show-config
  assert_status 0
  assert_contains "$ZT_OUT" $'# ~/.zco.config:4\neffort = xhigh\n'
  assert_eq "$ZT_ERR" '' "no header for --show-config"
  assert_not_run
}

# @scenario configuration: Command line reflected
test_show_config_reflects_the_command_line() {
  zt_zco opus -n --agent x --show-config
  assert_status 0
  assert_contains "$ZT_OUT" $'# command line\npermission_mode = plan\n'
  assert_contains "$ZT_OUT" $'# command line\nagent = x\n'
  assert_not_run
}

test_show_config_does_not_need_a_prompt_but_reports_config_errors() {
  zt_user_config 'efort = high'
  zt_zco opus --show-config
  assert_status 2
  assert_contains "$ZT_ERR" efort
}

# ------------------------------------------------------------------ prompt grammar

# @scenario prompt-grammar: Unknown level
test_unknown_level_run() {
  zt_zco opus -e extreme do it
  assert_status 2
  assert_contains "$ZT_ERR" 'low medium high xhigh max'
  assert_not_run
}

# @scenario prompt-grammar: Bare ultracode
test_bare_ultracode_run() {
  zt_zco opus ultracode refactor the parser
  assert_status 2
  assert_contains "$ZT_ERR" ultracode
  assert_contains "$ZT_ERR" --
  assert_not_run
}

# @scenario prompt-grammar: ultracode after an effort word
test_ultracode_after_an_effort_word_run() {
  zt_zco opus high ultracode refactor the parser
  assert_status 2
  assert_contains "$ZT_ERR" ultracode
  assert_not_run
}

# @scenario prompt-grammar: ultracode after the separator
test_ultracode_after_the_separator_run() {
  zt_zco opus -- ultracode refactor the parser
  assert_status 0
  assert_argv -p --model opus --permission-mode auto --strict-mcp-config -- 'ultracode refactor the parser'
}

# @scenario prompt-grammar: Line-mode options at run time
test_line_mode_options_at_run_time() {
  zt_zco opus --shell summarize the diff
  assert_status 0
  assert_argv_has -- 'summarize the diff'
  assert_stderr_body_empty "no error for --shell"
}

# @scenario prompt-grammar: Missing value
test_missing_value_run() {
  zt_zco opus --agent
  assert_status 2
  assert_contains "$ZT_ERR" --agent
  assert_not_run
}

# @scenario prompt-grammar: Typo in an option
test_typo_in_an_option_run() {
  zt_zco opus -x commit
  assert_status 2
  assert_contains "$ZT_ERR" "'-x'"
  assert_contains "$ZT_ERR" --
  assert_not_run
}

test_usage_errors_print_no_header() {
  zt_zco opus -x commit
  assert_match "$ZT_ERR" 'zco: unknown option*'
  assert_not_contains "$ZT_ERR" ' · '
}
