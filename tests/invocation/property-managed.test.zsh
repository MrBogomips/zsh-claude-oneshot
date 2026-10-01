# Property test, part "managed": managed flags and bundles in extra_args (see tests/lib/property.zsh).

zt_functions
source $ZT_TESTS/lib/property.zsh

# @scenario claude-invocation: No bypass flags under any configuration
test_never_pass_flags_managed() {
  zt_property '--model=opus' '--permission-mode' '-pc' '--strict-mcp-config'
}
