# Property test, part "allowed": extra_args that may be passed (see tests/lib/property.zsh).

zt_functions
source $ZT_TESTS/lib/property.zsh

# @scenario claude-invocation: No bypass flags under any configuration
test_never_pass_flags_allowed() {
  zt_property - '--name' 'nightly-summary'
}
