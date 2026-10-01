# Property test, part "never": never-pass flags in extra_args (see tests/lib/property.zsh).

zt_functions
source $ZT_TESTS/lib/property.zsh

# @scenario claude-invocation: No bypass flags under any configuration
test_never_pass_flags_never() {
  zt_property '--bare' '--dangerously-skip-permissions=true' '--allow-dangerously-skip-permissions' '--safe-mode'
}
