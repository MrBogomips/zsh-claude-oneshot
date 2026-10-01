# run-output: the header line, its markers and its styling.

zt_load
source $ZT_TESTS/lib/pty.zsh

zt_header() { local -a lines=( "${(@f)ZT_ERR}" ); REPLY=$lines[1] }

# @scenario run-output: Explicit effort
test_explicit_effort() {
  zt_mkdir_cd ~/proj
  zt_line 'opus xhigh commit local changes'
  zt_header
  assert_eq "$REPLY" 'opus · xhigh · auto · ~/proj'
}

# @scenario run-output: Effort left to settings
test_effort_left_to_settings() {
  zt_mkdir_cd ~/proj
  zt_line 'sonnet fix the typo'
  zt_header
  assert_eq "$REPLY" 'sonnet · settings · auto · ~/proj'
}

# @scenario run-output: Haiku dry run follow-up
test_haiku_dry_run_follow_up() {
  zt_mkdir_cd ~/proj
  zt_line 'haiku -n -c go ahead'
  zt_header
  assert_eq "$REPLY" 'haiku · n/a · plan · ~/proj · continue'
}

# @scenario run-output: Agent, skill and project file
test_agent_skill_and_project_file() {
  zt_write ~/proj/.zco.config 'agent = reviewer'
  cd ~/proj
  zt_line 'sonnet -s review the diff'
  zt_header
  assert_eq "$REPLY" 'sonnet · settings · auto · ~/proj · agent reviewer · /review · local config'
}

test_all_markers_in_order() {
  zt_write ~/proj/.zco.config 'agent = rev'
  cd ~/proj
  zt_line 'opus -r ID1 -s /pc --mcp-config m.json high go'
  zt_header
  assert_eq "$REPLY" 'opus · high · auto · ~/proj · resume · agent rev · /pc · mcp · local config'
  ZCO_MCP=on zt_line 'opus go'
  zt_header
  assert_eq "$REPLY" 'opus · settings · auto · ~/proj · agent rev · mcp · local config'
}

test_header_shows_the_model_not_the_prefixed_name() {
  ZCO_PREFIX=c- zt_load
  zt_mkdir_cd ~/w
  zt_line 'c-opus go'
  zt_header
  assert_eq "$REPLY" 'opus · settings · auto · ~/w'
}

test_named_directory_in_the_header() {
  zt_mkdir_cd ~/projects/zco
  hash -d zco=$HOME/projects/zco
  zt_line 'opus go'
  zt_header
  assert_eq "$REPLY" 'opus · settings · auto · ~zco'
}

test_ascii_outside_utf8_locales() {
  zt_mkdir_cd ~/proj
  LC_ALL=C zt_line 'opus xhigh go'
  zt_header
  assert_eq "$REPLY" 'opus - xhigh - auto - ~/proj'
}

test_no_header_for_quiet_help_show_config_and_errors() {
  zt_line 'opus -q go'
  assert_eq "$ZT_ERR" ''
  zt_line 'opus -h'
  assert_eq "$ZT_ERR" ''
  zt_line 'opus --show-config'
  assert_eq "$ZT_ERR" ''
  zt_line 'opus -x go'
  assert_not_contains "$ZT_ERR" ' · '
}

test_header_comes_before_notices() {
  zt_line 'haiku xhigh go'
  local -a lines=( "${(@f)ZT_ERR}" )
  assert_match "$lines[1]" 'haiku · n/a · auto · *'
  assert_contains "$lines[2]" 'does not support effort'
}

test_no_escape_sequences_when_stderr_is_not_a_terminal() {
  zt_line 'opus go'
  assert_not_contains "$ZT_ERR" $'\e'
}

# @scenario run-output: NO_COLOR set
test_no_color_set() {
  (( $+commands[jq] )) || zt_skip "jq is not installed"
  export FAKE_CLAUDE_STREAM=$ZT_TESTS/fixtures/stream-tools.jsonl
  zt_pty_start "source ${(q)ZT_PLUGIN}" 'export NO_COLOR=1'
  zt_pty_run 'zco opus summarize'
  zt_pty_stop
  assert_contains "$ZT_PTY_OUT" 'opus · settings · auto · ~'
  assert_contains "$ZT_PTY_OUT" '→ Bash  git diff --stat'
  assert_not_contains "$ZT_PTY_RAW" $'\e[2m'
  assert_not_contains "$ZT_PTY_RAW" $'\e[0m'
}

test_dim_styling_in_a_terminal() {
  (( $+commands[jq] )) || zt_skip "jq is not installed"
  export FAKE_CLAUDE_STREAM=$ZT_TESTS/fixtures/stream-tools.jsonl
  zt_pty_start "source ${(q)ZT_PLUGIN}"
  zt_pty_run 'zco opus summarize'
  zt_pty_stop
  assert_contains "$ZT_PTY_RAW" $'\e[2mopus · settings · auto · ~'
  assert_contains "$ZT_PTY_RAW" $'\e[2m→ Bash  git diff --stat'
}
