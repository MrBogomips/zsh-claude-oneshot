# Fixture for tests/self/harness.test.zsh: one passing and one failing test.

test_passes() {
  assert_eq 1 1
}

test_fails() {
  assert_eq 1 2 "one is not two"
}
