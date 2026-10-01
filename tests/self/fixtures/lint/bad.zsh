# Fixture for tests/self/lint.test.zsh: a deliberate syntax error (unterminated if).
if [[ -n $1 ]]; then
  print -r -- "$1"
