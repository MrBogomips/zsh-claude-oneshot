# model-commands: which commands are defined, and how they run.

# @scenario model-commands: Default model set
test_default_model_set() {
  zt_load
  local m
  for m in fable opus sonnet haiku; do
    assert_eq "$aliases[$m]" "noglob _zco_main $m $m" "$m is defined"
  done
  zt_line 'fable summarize'
  assert_argv_has --model fable
}

# @scenario model-commands: Custom model list
test_custom_model_list() {
  ZCO_MODELS=(opus haiku)
  zt_load
  assert_eq "$(zt_cmd_names)" 'haiku opus'
  assert_eq "${+aliases[sonnet]}" 0
  assert_eq "${+aliases[fable]}" 0
}

# @scenario model-commands: Model list as a string
test_model_list_as_a_string() {
  ZCO_MODELS="opus  sonnet"
  zt_load
  assert_eq "$(zt_cmd_names)" 'opus sonnet'
  assert_eq "${+aliases[haiku]}" 0
}

# @scenario model-commands: Model list from the user file
test_model_list_from_the_user_file() {
  zt_user_config 'models = opus haiku'
  zt_load
  assert_eq "$(zt_cmd_names)" 'haiku opus'
}

test_environment_beats_the_user_file_for_the_model_list() {
  zt_user_config $'models = opus haiku\nprefix = u-'
  ZCO_MODELS=sonnet ZCO_PREFIX=e- zt_load
  assert_eq "$(zt_cmd_names)" 'e-sonnet'
}

test_user_file_errors_do_not_disturb_loading() {
  zt_user_config $'efort = high\nmodels = opus'
  zt_run source $ZT_PLUGIN
  assert_eq "$ZT_OUT$ZT_ERR" '' "configuration errors are reported at the next run, not at load"
  assert_eq "$(zt_cmd_names)" opus
}

# @scenario model-commands: Prefixed commands
test_prefixed_commands() {
  ZCO_PREFIX="c-"
  zt_load
  assert_eq "${+aliases[opus]}" 0 "no command named opus"
  zt_line 'c-opus commit local changes'
  assert_status 0
  assert_argv_has --model opus
}

test_prefix_from_the_user_file() {
  zt_user_config 'prefix = ai-'
  zt_load
  assert_eq "$aliases[ai-haiku]" 'noglob _zco_main ai-haiku haiku'
}

# @scenario prompt-grammar: Error names the prefixed command
test_error_names_the_prefixed_command() {
  ZCO_PREFIX="c-"
  zt_load
  zt_line 'c-opus -x commit'
  assert_status 2
  assert_match "$ZT_ERR" 'c-opus: *'
  assert_not_run
}

# @scenario prompt-grammar: Help for a model command
test_help_for_a_model_command() {
  zt_load
  zt_line 'sonnet -h'
  assert_status 0
  assert_contains "$ZT_OUT" 'usage: sonnet'
  assert_contains "$ZT_OUT" 'model sonnet'
  assert_eq "$ZT_ERR" ''
  assert_not_run
}

# @scenario model-commands: Empty model list
test_empty_model_list() {
  ZCO_MODELS=()
  zt_load
  assert_eq ${#_zco_cmds} 0
  assert_eq "${+aliases[opus]}" 0
  zt_zco opus commit local changes
  assert_status 0
  assert_argv_has --model opus
}

test_empty_model_list_from_the_user_file() {
  zt_user_config 'models ='
  zt_load
  assert_eq ${#_zco_cmds} 0
  zt_zco opus x
  assert_status 0
}

# @scenario model-commands: Name taken by an existing function
test_name_taken_by_an_existing_function() {
  haiku() { print -r -- 'my haiku' }
  zt_run source $ZT_PLUGIN
  local -a lines=( "${(@f)ZT_ERR}" )
  assert_eq $#lines 1 "one warning"
  assert_contains "$ZT_ERR" haiku
  assert_contains "$ZT_ERR" ZCO_PREFIX
  assert_eq "$(haiku)" 'my haiku' "the function is unchanged"
  assert_eq "${+aliases[haiku]}" 0
  assert_eq "$aliases[opus]" 'noglob _zco_main opus opus'
}

test_names_taken_by_aliases_commands_and_builtins() {
  alias sonnet='print mine'
  mkdir -p $ZT_TMP/bin
  print -r -- '#!/bin/sh' > $ZT_TMP/bin/fable
  chmod +x $ZT_TMP/bin/fable
  path=( $ZT_TMP/bin $path )
  ZCO_MODELS=(fable opus sonnet echo) zt_run source $ZT_PLUGIN
  local -a lines=( "${(@f)ZT_ERR}" )
  assert_eq $#lines 3 "one warning per taken name"
  assert_eq "$aliases[sonnet]" 'print mine'
  assert_eq "$(zt_cmd_names)" opus
}

test_zco_taken_by_an_existing_function() {
  zco() { print -r -- 'my zco' }
  zt_run source $ZT_PLUGIN
  assert_contains "$ZT_ERR" zco
  assert_eq "$(zco)" 'my zco'
  assert_eq "$aliases[opus]" 'noglob _zco_main opus opus'
}

# @scenario model-commands: Entry with brackets
test_entry_with_brackets() {
  ZCO_MODELS=(opus 'sonnet[1m]')
  zt_run source $ZT_PLUGIN
  local -a lines=( "${(@f)ZT_ERR}" )
  assert_eq $#lines 1 "one warning"
  assert_contains "$ZT_ERR" 'sonnet[1m]'
  assert_eq "$(zt_cmd_names)" opus
}

test_invalid_entries_are_skipped() {
  ZCO_MODELS=(-opus 'has space' ok.model_1-2 '')
  zt_run source $ZT_PLUGIN
  assert_eq "$(zt_cmd_names)" ok.model_1-2
  assert_contains "$ZT_ERR" "'-opus'"
  assert_contains "$ZT_ERR" "'has space'"
}

# @scenario model-commands: Changing a run-time setting in a live shell
test_changing_a_run_time_setting_in_a_live_shell() {
  zt_load
  zt_line 'opus fix the typo'
  assert_argv_has --permission-mode auto
  export ZCO_PERMISSION_MODE=acceptEdits
  zt_line 'opus fix the typo'
  assert_argv_has --permission-mode acceptEdits
}

# @scenario model-commands: Boolean spelled differently
test_boolean_spelled_differently() {
  zt_load
  ZCO_MCP=Yes zt_line 'opus summarize'
  assert_status 0
  assert_argv_lacks --strict-mcp-config
}

# @scenario model-commands: Invalid boolean
test_invalid_boolean() {
  zt_load
  ZCO_MCP=maybe zt_line 'opus summarize'
  assert_status 2
  assert_contains "$ZT_ERR" ZCO_MCP
  assert_not_run
}

# @scenario model-commands: Glob characters with raw-line capture off
test_glob_characters_with_raw_line_capture_off() {
  zt_load
  touch a.md b.md
  ZCO_RAW_LINE=0 zt_line 'opus which *.md files mention [install]?'
  assert_status 0
  assert_not_contains "$ZT_ERR" 'no matches found'
  assert_argv_has -- 'which *.md files mention [install]?'
}

test_commands_behave_exactly_like_zco() {
  zt_load
  zt_line 'opus -n -a rev xhigh do it'
  local -a via_alias
  zt_claude_argv; via_alias=( "${reply[@]}" )
  zt_zco opus -n -a rev xhigh do it
  assert_argv "${via_alias[@]}"
}
