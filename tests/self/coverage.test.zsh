# tests/scenario-coverage.zsh

test_untagged_scenario_is_named_and_fails() {
  local fx=$ZT_TESTS/self/fixtures/coverage
  zt_run zsh -f $ZT_TESTS/scenario-coverage.zsh --specs $fx/specs --tests $fx/tests
  assert_status 1
  assert_contains "$ZT_OUT" "MISSING demo: Untagged scenario"
  assert_not_contains "$ZT_OUT" "MISSING demo: Tagged scenario"
  assert_contains "$ZT_OUT" "UNKNOWN"
  assert_contains "$ZT_OUT" "demo: No such scenario"
  assert_contains "$ZT_OUT" "# scenario coverage: 1/2 (50%), 1 unknown tags"
}

test_full_coverage_passes() {
  zt_write $ZT_TMP/specs/cap/spec.md $'#### Scenario: Only one\n- **WHEN** x'
  zt_write $ZT_TMP/tests/a.test.zsh $'# @scenario cap: Only one\ntest_a() { : }'
  zt_run zsh -f $ZT_TESTS/scenario-coverage.zsh --specs $ZT_TMP/specs --tests $ZT_TMP/tests
  assert_status 0
  assert_contains "$ZT_OUT" "# scenario coverage: 1/1 (100%), 0 unknown tags"
}
