# The runner refuses to run when `claude` is not the test double.

test_runner_aborts_when_another_claude_comes_first() {
  local copy=$ZT_TMP/copy/tests other=$ZT_TMP/other
  mkdir -p -- $copy $other
  cp -R $ZT_TESTS/lib $ZT_TESTS/bin $ZT_TESTS/run.zsh $copy/
  chmod -x $copy/bin/claude   # the double is no longer eligible, so `other` comes first
  print -rl -- '#!/bin/sh' "echo real > ${(q)ZT_TMP}/real-claude-ran" > $other/claude
  chmod +x $other/claude
  zt_write $copy/sample.test.zsh "test_sample() { : > ${(q)ZT_TMP}/test-ran }"

  zt_run env PATH=$other:$PATH zsh -f $copy/run.zsh

  assert_status 2
  assert_contains "$ZT_OUT" "Bail out!"
  assert_contains "$ZT_OUT" "$other/claude"
  assert_file_absent $ZT_TMP/test-ran "no test may run"
  assert_file_absent $ZT_TMP/real-claude-ran
}

test_runner_accepts_the_double() {
  local copy=$ZT_TMP/copy/tests
  mkdir -p -- $copy
  cp -R $ZT_TESTS/lib $ZT_TESTS/bin $ZT_TESTS/run.zsh $copy/
  zt_write $copy/sample.test.zsh "test_sample() { : > ${(q)ZT_TMP}/test-ran }"
  zt_run zsh -f $copy/run.zsh
  assert_status 0
  assert_true "the sample test runs" test -e $ZT_TMP/test-ran
}
