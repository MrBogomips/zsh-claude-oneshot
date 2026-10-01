# model-commands: independence from the user's shell options, and glob safety.

ZT_HOSTILE_OPTIONS='ksh_arrays sh_word_split no_unset err_exit extended_glob null_glob'

# @scenario model-commands: Unusual options set
test_unusual_options_set() {
  zt_load
  zt_line 'opus xhigh commit local changes'
  local -a normal
  zt_claude_argv; normal=( "${reply[@]}" )
  ZT_USER_OPTIONS='ksh_arrays sh_word_split no_unset extended_glob' zt_line 'opus xhigh commit local changes'
  assert_status 0
  assert_argv "${normal[@]}"
}

test_loading_under_unusual_options() {
  ZT_USER_OPTIONS=$ZT_HOSTILE_OPTIONS zt_run source $ZT_PLUGIN
  assert_status 0
  assert_eq "$ZT_OUT$ZT_ERR" ''
  assert_eq "$aliases[opus]" 'noglob _zco_main opus opus'
}

test_suites_pass_again_under_unusual_options() {
  zt_run env ZT_USER_OPTIONS=$ZT_HOSTILE_OPTIONS zsh -f $ZT_TESTS/run.zsh \
    $ZT_TESTS/models $ZT_TESTS/unit/config.test.zsh $ZT_TESTS/unit/config-show.test.zsh \
    $ZT_TESTS/invocation/{argv,command,options,runs,stdin}.test.zsh
  assert_status 0 "the model-command, invocation and configuration tests must pass under: $ZT_HOSTILE_OPTIONS"
  assert_contains "$ZT_OUT" ' 0 failed'
}

test_harness_detects_a_changed_option() {
  sneaky() { setopt glob_dots }
  ZT_USER_OPTIONS=ksh_arrays zt__with_options sneaky
  assert_ne "$ZT__BEFORE" "$ZT__AFTER" "a changed option must show"
  assert_true "options are restored afterwards" eval '[[ ! -o glob_dots && ! -o ksh_arrays ]]'
}
