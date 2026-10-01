# tests/check-hygiene.zsh
# The offending lines are assembled at run time so that no such line is stored in the repository.

test_flags_home_paths_attribution_and_generated_notes() {
  local abs="/Us""ers/someone/project" trailer="Co-Authored""-By: Some Bot <bot@example.com>"
  local note="Gene""rated with some tool"
  zt_write $ZT_TMP/sample.md "first line
path: $abs
$trailer
$note
a relative path: tests/fixtures/home/x.zsh
described pattern: $abs <!-- hygiene: allow -->"
  zt_run zsh -f $ZT_TESTS/check-hygiene.zsh $ZT_TMP/sample.md
  assert_status 1
  assert_contains "$ZT_OUT" "sample.md:2:path:"
  assert_contains "$ZT_OUT" "sample.md:3:"
  assert_contains "$ZT_OUT" "sample.md:4:"
  assert_not_contains "$ZT_OUT" "sample.md:1:"
  assert_not_contains "$ZT_OUT" "sample.md:5:"
  assert_not_contains "$ZT_OUT" "sample.md:6:"
  assert_contains "$ZT_OUT" "3 problems"
}

test_passes_on_the_repository() {
  zt_run zsh -f $ZT_TESTS/check-hygiene.zsh
  assert_status 0
  assert_contains "$ZT_OUT" "0 problems"
}
