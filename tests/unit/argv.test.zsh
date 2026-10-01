# _zco_extra_ok (the extra_args filter) and _zco_argv's guard against never-pass flags.

zt_functions

assert_extra() {   # arg expected-status
  REPLY=
  _zco_extra_ok "$1"
  assert_eq $? $2 "_zco_extra_ok ${(qqqq)1} (message: $REPLY)"
  (( $2 == 0 )) || assert_contains "$REPLY" "$1"
}

test_never_pass_flags_are_refused() {
  local f
  for f in --bare --safe-mode --dangerously-skip-permissions --allow-dangerously-skip-permissions \
           --dangerously-skip-permissions=true --bare=1; do
    assert_extra $f 1
  done
}

test_managed_flags_are_refused_plain_and_with_equals() {
  local f
  for f in -p --print --model --permission-mode --effort --output-format --input-format --verbose \
           --continue -c --resume -r --strict-mcp-config --no-session-persistence --max-budget-usd \
           --agent --system-prompt --system-prompt-file --append-system-prompt \
           --append-system-prompt-file --add-dir --allowed-tools --allowedTools --disallowed-tools \
           --disallowedTools --settings --mcp-config --fallback-model --max-turns \
           --effort=high --model=opus --agent=x; do
    assert_extra $f 1
  done
}

test_short_option_bundles_are_refused() {
  assert_extra -pc 1
  assert_extra -dv 1
}

test_other_arguments_pass() {
  local a
  for a in --name nightly-summary -d --debug --mcp-debug value 'two words' --plugin-dir=x ''; do
    assert_extra "$a" 0
  done
}
