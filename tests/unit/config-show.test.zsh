# _zco_config_show: the --show-config output. The run through the command is in tests/invocation/.

zt_functions

zt_show() {   # model arg...: resolve, then print the configuration into ZT_OUT
  zt_settings "$@"
  assert_eq $ZT_RC 0 "$REPLY"
  zt_run _zco_config_show $1 $1
  assert_status 0
}

# @scenario configuration: Show where the effort comes from
test_show_where_the_effort_comes_from() {
  zt_user_config $'agent = reviewer\n# a comment\n[opus]\neffort = xhigh'
  zt_show opus --show-config
  assert_contains "$ZT_OUT" $'# ~/.zco.config:4\neffort = xhigh\n'
  assert_contains "$ZT_OUT" $'# ~/.zco.config:1\nagent = reviewer\n'
}

# @scenario configuration: Command line reflected
test_command_line_reflected() {
  zt_show opus -n --show-config
  assert_contains "$ZT_OUT" $'# command line\npermission_mode = plan\n'
}

test_header_names_the_files_found() {
  zt_user_config 'effort = low'
  zt_write ~/proj/.zco.config 'agent = rev'
  cd ~/proj
  zt_show opus --show-config
  assert_contains "$ZT_OUT" '# user file:    ~/.zco.config'
  assert_contains "$ZT_OUT" '# project file: ~/proj/.zco.config'
  rm ~/proj/.zco.config ~/.zco.config
  zt_show opus --show-config
  assert_contains "$ZT_OUT" '# user file:    none'
  assert_contains "$ZT_OUT" '# project file: none'
}

test_every_key_appears_once_in_schema_order() {
  setopt local_options extended_glob
  local -A zk
  _zco_keys
  zt_show opus --show-config
  local -a got
  got=( ${${(M)${(f)ZT_OUT}:#[a-z_]## =*}%% =*} )
  assert_eq "${(j: :)got}" "${zk[keys]}"
}

test_built_in_defaults_are_shown() {
  zt_show opus --show-config
  assert_contains "$ZT_OUT" $'# built-in\npermission_mode = auto\n'
  assert_contains "$ZT_OUT" $'# built-in\nclaude_cmd = claude\n'
  assert_contains "$ZT_OUT" $'# built-in\neffort =\n'
  assert_contains "$ZT_OUT" $'# built-in\nsession_persistence = true\n'
}

test_lists_show_one_line_per_entry() {
  zt_write ~/proj/.zco.config $'allowed_tools = Bash(git *)\nallowed_tools = Edit'
  cd ~/proj
  zt_show opus --show-config --allowed-tools Read
  assert_contains "$ZT_OUT" $'# ~/proj/.zco.config:1\nallowed_tools = Bash(git *)\n# ~/proj/.zco.config:2\nallowed_tools = Edit\n# command line\nallowed_tools = Read\n'
}

test_values_with_outer_spaces_are_quoted() {
  zt_user_config 'append_system_prompt = "  Answer tersely.  "'
  zt_show opus --show-config
  assert_contains "$ZT_OUT" $'append_system_prompt = "  Answer tersely.  "\n'
}

test_output_parses_back_as_a_user_file() {
  zt_user_config $'effort = high\nappend_system_prompt = "  x  "\nallowed_tools = Bash(git *)\nmcp = yes'
  zt_show opus --show-config
  print -r -- "$ZT_OUT" > ~/.zco.config
  zt_settings opus x
  assert_eq $ZT_RC 0 "the --show-config output must parse: $REPLY"
  assert_setting effort high
  assert_setting append_system_prompt '  x  '
  assert_setting mcp true
}

test_environment_source_is_the_variable_name() {
  ZCO_AGENT=reviewer zt_show opus --show-config
  assert_contains "$ZT_OUT" $'# ZCO_AGENT\nagent = reviewer\n'
}
