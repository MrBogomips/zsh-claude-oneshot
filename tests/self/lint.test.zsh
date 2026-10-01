# tests/run.zsh --lint

test_lint_fails_on_a_syntax_error() {
  zt_run zsh -f $ZT_TESTS/run.zsh --lint $ZT_TESTS/self/fixtures/lint
  assert_status 1
  assert_contains "$ZT_OUT" "not ok - zsh -n tests/self/fixtures/lint/bad.zsh"
}

test_lint_passes_on_the_repository() {
  zt_run zsh -f $ZT_TESTS/run.zsh --lint
  assert_status 0
  assert_contains "$ZT_OUT" "ok - zsh -n zsh-claude-oneshot.plugin.zsh"
  assert_contains "$ZT_OUT" "ok - zsh -n tests/bin/claude"
  assert_contains "$ZT_OUT" "ok - zsh -n tests/run.zsh"
  assert_not_contains "$ZT_OUT" "fixtures/lint/bad.zsh"
}
