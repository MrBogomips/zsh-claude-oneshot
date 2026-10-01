# Fixture for tests/self/harness.test.zsh: the invoking user's home and ZCO_ variables never leak in.

test_home_is_private() {
  assert_ne "$HOME" "$ZT_OUTER_HOME" "HOME must be a fresh temporary directory"
  assert_file_absent $HOME/.zco.config
  assert_eq "${+ZCO_CONFIG}" 0 "ZCO_CONFIG must be unset"
  assert_eq "${+ZCO_EFFORT}" 0 "ZCO_EFFORT must be unset"
}
