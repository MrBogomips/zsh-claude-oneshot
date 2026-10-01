# The runner and the harness themselves.

test_runner_reports_passing_and_failing_tests() {
  zt_run zsh -f $ZT_TESTS/run.zsh $ZT_TESTS/self/fixtures/runner
  assert_status 1
  assert_contains "$ZT_OUT" "ok 1 - tests/self/fixtures/runner/pass-fail.test.zsh: test_passes"
  assert_contains "$ZT_OUT" "not ok 2 - tests/self/fixtures/runner/pass-fail.test.zsh: test_fails"
  assert_contains "$ZT_OUT" "#   one is not two"
  assert_contains "$ZT_OUT" "1..2"
}

test_real_home_config_is_never_read() {
  local outer=$ZT_TMP/outer-home
  zt_write $outer/.zco.config 'efort = high'
  zt_run env HOME=$outer ZCO_CONFIG=$outer/.zco.config ZCO_EFFORT=max \
    zsh -f $ZT_TESTS/run.zsh $ZT_TESTS/self/fixtures/isolated-home
  assert_status 0
  assert_contains "$ZT_OUT" "ok 1 - tests/self/fixtures/isolated-home/isolated-home.test.zsh: test_home_is_private"
}

test_each_test_gets_its_own_home() {
  assert_match "$HOME" "$ZT_TMP/home"
  assert_eq "$PWD" "$HOME"
  assert_eq "$(whence -p claude)" "$ZT_TESTS/bin/claude"
}

test_runner_counts_a_crashing_file_as_failed() {
  zt_write $ZT_TMP/crash/crash.test.zsh 'test_x() { assert_eq 1 1 }
kill -9 $$'
  zt_run zsh -f $ZT_TESTS/run.zsh $ZT_TMP/crash
  assert_status 1
  assert_contains "$ZT_OUT" "not ok 1 -"
}
