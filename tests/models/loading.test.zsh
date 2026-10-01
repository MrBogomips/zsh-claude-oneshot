# model-commands: loading the plugin.

# @scenario model-commands: Sourced from another directory
test_sourced_from_another_directory() {
  zt_mkdir_cd $ZT_TMP/elsewhere
  zt_run source $ZT_PLUGIN
  assert_status 0
  assert_eq "$ZT_OUT$ZT_ERR" '' "loading is silent"
  zt_line 'opus summarize'
  assert_status 0
  assert_argv_has --model opus
  zt_zco sonnet summarize
  assert_argv_has --model sonnet
}

test_sourced_through_a_relative_path() {
  cd $ZT_ROOT:h
  zt_run source ./${ZT_ROOT:t}/zsh-claude-oneshot.plugin.zsh
  assert_status 0
  zt_mkdir_cd $ZT_TMP/elsewhere
  zt_line 'haiku summarize'
  assert_status 0
  assert_argv_has --model haiku
}

# @scenario model-commands: Sourced through a symlink
test_sourced_through_a_symlink() {
  mkdir -p $ZT_TMP/links
  ln -s $ZT_PLUGIN $ZT_TMP/links/zsh-claude-oneshot.plugin.zsh
  zt_mkdir_cd $ZT_TMP/elsewhere
  zt_run source $ZT_TMP/links/zsh-claude-oneshot.plugin.zsh
  assert_status 0
  assert_eq "$fpath[1]" "$ZT_ROOT/functions" "functions come from the real directory"
  assert_file_absent $ZT_TMP/links/functions
  zt_line 'opus summarize'
  assert_status 0
  assert_argv_has --model opus
}

# @scenario model-commands: Sourced twice
test_sourced_twice() {
  zt_run source $ZT_PLUGIN
  zt_run source $ZT_PLUGIN
  assert_status 0
  assert_eq "$ZT_OUT$ZT_ERR" '' "the second load is silent too"
  assert_eq "$aliases[opus]" 'noglob _zco_main opus opus'
  local -a names=( ${(k)aliases} )
  names=( ${(M)names:#(fable|opus|sonnet|haiku)} )
  assert_eq $#names 4 "one alias per model"
  assert_eq "$(zt_cmd_names)" 'fable haiku opus sonnet'
  local -a dirs=( ${(M)fpath:#$ZT_ROOT/functions} )
  assert_eq $#dirs 1 "functions/ added to fpath once"
}

test_reloading_with_a_new_prefix_removes_the_old_commands() {
  zt_load
  ZCO_PREFIX=c- zt_run source $ZT_PLUGIN
  assert_eq "$ZT_ERR" ''
  assert_eq "${+aliases[opus]}" 0
  assert_eq "$aliases[c-opus]" 'noglob _zco_main c-opus opus'
}

# @scenario model-commands: Old zsh
test_old_zsh() {
  is-at-least() { return 1 }
  zt_run source $ZT_PLUGIN
  assert_eq "$ZT_OUT" ''
  local -a lines=( "${(@f)ZT_ERR}" )
  assert_eq $#lines 1 "exactly one warning"
  assert_contains "$ZT_ERR" 5.3
  assert_eq "${+aliases[opus]}" 0 "no command defined"
  assert_eq "${+functions[zco]}" 0 "zco not defined"
  assert_eq "${+functions[_zco_main]}" 0
}
