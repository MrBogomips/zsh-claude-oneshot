# The coexistence tests skip with a notice when tests/.deps/ is absent.

test_coexistence_tests_skip_without_deps() {
  zt_run env ZT_DEPS_DIR=$ZT_TMP/no-deps zsh -f $ZT_TESTS/run.zsh $ZT_TESTS/rawline/coexist.test.zsh
  assert_status 0
  assert_contains "$ZT_OUT" 'test_loaded_after_zsh_syntax_highlighting_and_autosuggestions # SKIP tests/.deps/ is absent: run zsh tests/fetch-deps.zsh'
  assert_contains "$ZT_OUT" 'test_loaded_before_zsh_syntax_highlighting_and_autosuggestions # SKIP'
  assert_contains "$ZT_OUT" '2 skipped'
}
