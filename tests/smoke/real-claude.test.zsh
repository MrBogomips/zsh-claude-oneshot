# Smoke test against the real Claude Code CLI. Opt-in: runs only with ZCO_SMOKE=1, never in CI.
#   ZCO_SMOKE=1 zsh tests/run.zsh tests/smoke
# It uses your own HOME and CLAUDE_CONFIG_DIR. The probes make no API call; the rest makes a few
# small haiku calls.

zt_load

zt_smoke_setup() {
  [[ ${ZCO_SMOKE:-} == 1 ]] || zt_skip "set ZCO_SMOKE=1 to run against the real Claude Code CLI"
  local -a all
  all=( ${(f)"$(whence -pa claude)"} )
  all=( ${(u)all:#$ZT_TESTS/bin/claude} )
  (( $#all )) || zt_skip "no real claude on PATH"
  typeset -ga ZT_REAL
  ZT_REAL=( env HOME=$ZT_OUTER_HOME )
  [[ -n ${ZT_OUTER_CLAUDE_CONFIG_DIR:-} ]] && ZT_REAL+=( CLAUDE_CONFIG_DIR=$ZT_OUTER_CLAUDE_CONFIG_DIR )
  ZT_REAL+=( $all[1] )
  ZCO_CLAUDE_CMD=( "${ZT_REAL[@]}" )
  zt_mkdir_cd $ZT_TMP/work
}

# ------------------------------------------------------------------ parse-time probes, no API call

test_hidden_flags_are_still_accepted() {
  zt_smoke_setup
  local flag
  for flag in '--system-prompt-file /dev/null' '--append-system-prompt-file /dev/null' '--max-turns 1'; do
    zt_run eval "\"\${ZT_REAL[@]}\" -p $flag"
    assert_not_contains "${(L)ZT_OUT}${(L)ZT_ERR}" 'unknown option' "$flag must still be accepted"
  done
}

test_skill_is_still_unknown() {
  zt_smoke_setup
  zt_run "${ZT_REAL[@]}" -p --skill x
  assert_contains "${(L)ZT_OUT}${(L)ZT_ERR}" 'unknown option' "--skill is a real flag now: revisit design Decision 5"
}

test_missing_agent_is_rejected() {
  zt_smoke_setup
  zt_run "${ZT_REAL[@]}" -p --agent zco-smoke-no-such-agent
  assert_ne $ZT_RC 0
  assert_contains "${(L)ZT_OUT}${(L)ZT_ERR}" 'not found'
}

# ------------------------------------------------------------------ haiku calls

test_separator_stops_a_variadic_flag() {
  zt_smoke_setup
  zt_zco haiku -q --add-dir /tmp -- '-v: reply with the word pong and nothing else'
  assert_status 0
  assert_contains "${(L)ZT_OUT}" pong
}

test_auto_and_plan_modes_are_accepted() {
  zt_smoke_setup
  zt_zco haiku -q reply with the word ok and nothing else
  assert_status 0 "permission mode auto"
  assert_ne "$ZT_OUT" ''
  zt_zco haiku -n -q reply with the word ok and nothing else
  assert_status 0 "permission mode plan"
  assert_ne "$ZT_OUT" ''
}

test_stream_json_field_names_read_by_the_renderer() {
  zt_smoke_setup
  print -r -- '# notes' > notes.md
  local ask='Use one of your tools to list the files in the current directory (any read-only tool), then reply with the number of files.'
  zt_run "${ZT_REAL[@]}" -p --model haiku --strict-mcp-config --permission-mode plan \
    --output-format stream-json --verbose -- "$ask"
  assert_status 0
  local field
  for field in '"type":"assistant"' '"content":' '"type":"tool_use"' '"name":' '"input":' \
               '"type":"result"' '"subtype":"success"' '"result":' '"duration_ms":' '"num_turns":' \
               '"total_cost_usd":'; do
    assert_contains "$ZT_OUT" "$field" "stream-json field $field"
  done
  zt_zco haiku -v -n "$ask"
  assert_status 0
  assert_match "$ZT_ERR" "*"$'\n''→ [A-Za-z]*'
  assert_match "$ZT_ERR" "*done · *s · * turn*"
  assert_ne "$ZT_OUT" ''
}

test_fast_start() {
  zt_smoke_setup
  zmodload zsh/datetime
  typeset -F start=$EPOCHREALTIME
  zt_zco haiku -q reply with the word pong and nothing else
  typeset -F seconds=$(( EPOCHREALTIME - start ))
  print -r -- "fast start: ${seconds}s"
  assert_status 0
  (( seconds < 20 )) || zt_fail "a trivial haiku prompt took ${seconds}s"
}
