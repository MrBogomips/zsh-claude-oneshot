# Configuration files: discovery, format, keys, precedence, lists, paths and validation.
# These tests call the configuration functions directly; the runs through the commands, which
# check the Claude Code arguments, are in tests/invocation/.

zt_functions

assert_config_error() {   # needle...
  assert_ne $ZT_RC 0 "the configuration should be rejected"
  local n
  for n in "$@"; do assert_contains "$REPLY" "$n"; done
}

# ------------------------------------------------------------------ locations

# @scenario configuration: Nearest project file wins
test_nearest_project_file_wins() {
  zt_write ~/work/a/.zco.config 'effort = low'
  zt_write ~/work/a/b/.zco.config 'effort = high'
  zt_mkdir_cd ~/work/a/b/c
  zt_settings opus summarize
  assert_eq $ZT_RC 0
  assert_eq "$zco_files[2]" "$HOME/work/a/b/.zco.config"
  assert_setting effort high '~/work/a/b/.zco.config:1'
}

# @scenario configuration: Home file is not a project file
test_home_file_is_not_a_project_file() {
  zt_user_config 'effort = medium'
  zt_mkdir_cd ~/work/a
  zt_settings opus summarize
  assert_eq "$zco_files[1]" "$HOME/.zco.config"
  assert_eq "$zco_files[2]" ''
  assert_setting effort medium '~/.zco.config:1'
}

# @scenario configuration: Alternative user file
test_alternative_user_file() {
  zt_write ~/dotfiles/zco.config 'agent = from-dotfiles'
  zt_user_config 'effort = max'
  export ZCO_CONFIG=~/dotfiles/zco.config
  zt_mkdir_cd ~/work
  zt_settings opus summarize
  assert_eq "$zco_files[1]" "$HOME/dotfiles/zco.config"
  assert_eq "$zco_files[2]" '' "~/.zco.config must not become a project file"
  assert_setting agent from-dotfiles
  assert_setting effort ''
}

# @scenario configuration: Project lookup turned off
test_project_lookup_turned_off() {
  zt_mkdir_cd ~/proj
  zt_write ~/proj/.zco.config 'effort = low'
  ZCO_LOCAL_CONFIG=0 zt_settings opus summarize
  assert_eq "$zco_files[2]" ''
  assert_setting effort ''
  ZCO_LOCAL_CONFIG=off zt_settings opus summarize
  assert_eq "$zco_files[2]" ''
  ZCO_LOCAL_CONFIG=1 zt_settings opus summarize
  assert_eq "$zco_files[2]" "$HOME/proj/.zco.config"
}

test_invalid_local_config_switch() {
  ZCO_LOCAL_CONFIG=sometimes zt_settings opus summarize
  assert_config_error ZCO_LOCAL_CONFIG
}

# @scenario configuration: No configuration files
test_no_configuration_files() {
  zt_run zt_settings opus summarize
  assert_eq $ZT_RC 0
  assert_eq "$ZT_ERR" '' "no warning"
  assert_eq "${zco_files[1]}${zco_files[2]}" ''
  assert_setting permission_mode auto built-in
  assert_setting effort '' built-in
  assert_setting session_persistence true built-in
  assert_setting mcp false built-in
  assert_setting claude_cmd claude built-in
}

test_project_lookup_reaches_the_root() {
  zt_mkdir_cd $ZT_TMP/outside/deep/dir
  zt_settings opus x
  assert_eq $ZT_RC 0
  assert_eq "$zco_files[2]" ''
}

# ------------------------------------------------------------------ format

# @scenario configuration: Sections apply per model
test_sections_apply_per_model() {
  zt_user_config $'effort = medium\n[opus]\neffort = xhigh'
  zt_settings opus summarize
  assert_setting effort xhigh '~/.zco.config:3'
  zt_settings sonnet summarize
  assert_setting effort medium '~/.zco.config:1'
}

# @scenario configuration: Quoted value keeps spaces
test_quoted_value_keeps_spaces() {
  zt_user_config 'append_system_prompt = "  Answer tersely.  "'
  zt_settings opus x
  assert_setting append_system_prompt '  Answer tersely.  '
  zt_user_config "append_system_prompt = 'single'"
  zt_settings opus x
  assert_setting append_system_prompt single
  zt_user_config "append_system_prompt = 'mismatched\""
  zt_settings opus x
  assert_setting append_system_prompt "'mismatched\""
}

# @scenario configuration: No evaluation
test_no_evaluation() {
  local target=$ZT_TMP/pwned
  zt_user_config "system_prompt = \$(touch $target)
append_system_prompt = \`touch $target\` \${HOME} ~ *"
  zt_settings opus x
  assert_eq $ZT_RC 0
  assert_setting system_prompt "\$(touch $target)"
  assert_setting append_system_prompt "\`touch $target\` \${HOME} ~ *"
  assert_file_absent $target
}

test_parser_edge_cases() {
  print -rn -- $'# comment\n  ; another comment\n\nagent = a = b\nappend_system_prompt = use # for headings\nfallback_model = sonnet' > ~/.zco.config
  zt_settings opus x
  assert_eq $ZT_RC 0
  assert_setting agent 'a = b'
  assert_setting append_system_prompt 'use # for headings'
  assert_setting fallback_model sonnet '~/.zco.config:6'   # no final newline
}

test_crlf_line_endings() {
  print -rn -- $'effort = high\r\n[opus]\r\nagent = rev\r\n' > ~/.zco.config
  zt_settings opus x
  assert_eq $ZT_RC 0
  assert_setting effort high
  assert_setting agent rev
}

test_section_header_with_surrounding_spaces() {
  zt_user_config $'  [ opus ]  \neffort = low'
  zt_settings opus x
  assert_setting effort low
  zt_settings sonnet x
  assert_setting effort ''
}

test_empty_scalar_value_clears_lower_layers() {
  zt_user_config 'agent = reviewer'
  zt_write ~/proj/.zco.config 'agent ='
  cd ~/proj
  zt_settings opus x
  assert_setting agent '' '~/proj/.zco.config:1'
}

test_later_line_wins_within_a_layer() {
  zt_user_config $'effort = low\neffort = high'
  zt_settings opus x
  assert_setting effort high '~/.zco.config:2'
}

test_malformed_line() {
  zt_user_config $'effort = low\njust some words'
  zt_settings opus x
  assert_config_error '~/.zco.config:2'
}

test_load_time_key_in_a_section_is_an_error() {
  zt_user_config $'[opus]\nmodels = opus'
  zt_settings opus x
  assert_config_error '~/.zco.config:2' models
}

test_section_names_are_not_validated() {
  zt_user_config $'[opus[1m]]\neffort = max\n[anything at all!]\neffort = low'
  zt_settings 'opus[1m]' x
  assert_eq $ZT_RC 0
  assert_setting effort max
}

# ------------------------------------------------------------------ keys and the environment

# @scenario configuration: Scalar key through the environment
test_scalar_key_through_the_environment() {
  ZCO_AGENT=reviewer zt_settings opus x
  assert_setting agent reviewer ZCO_AGENT
}

test_every_scalar_key_has_its_variable() {
  local -A zk
  _zco_keys
  local k
  ZCO_PERMISSION_MODE=plan ZCO_MAX_TURNS=3 ZCO_MAX_BUDGET_USD=1.5 ZCO_FALLBACK_MODEL=haiku \
  ZCO_SYSTEM_PROMPT=s ZCO_APPEND_SYSTEM_PROMPT_FILE=a.md ZCO_SETTINGS=s.json ZCO_MCP=on \
  ZCO_SESSION_PERSISTENCE=no zt_settings opus x
  assert_eq $ZT_RC 0 "$REPLY"
  assert_setting permission_mode plan ZCO_PERMISSION_MODE
  assert_setting max_turns 3 ZCO_MAX_TURNS
  assert_setting max_budget_usd 1.5
  assert_setting fallback_model haiku
  assert_setting system_prompt s
  assert_setting append_system_prompt_file a.md
  assert_setting settings s.json
  assert_setting mcp true ZCO_MCP
  assert_setting session_persistence false ZCO_SESSION_PERSISTENCE
}

test_invalid_environment_values_name_the_variable() {
  ZCO_MAX_TURNS=0 zt_settings opus x;          assert_config_error ZCO_MAX_TURNS
  ZCO_MAX_BUDGET_USD=cheap zt_settings opus x; assert_config_error ZCO_MAX_BUDGET_USD
  ZCO_EFFORT=turbo zt_settings opus x;         assert_config_error ZCO_EFFORT
  ZCO_EFFORT_OPUS=turbo zt_settings opus x;    assert_config_error ZCO_EFFORT_OPUS
  ZCO_MCP=maybe zt_settings opus x;            assert_config_error ZCO_MCP
}

test_invalid_command_line_values_name_the_option() {
  zt_settings opus --max-turns 0 x;         assert_config_error --max-turns
  zt_settings opus --max-turns 1.5 x;       assert_config_error --max-turns
  zt_settings opus --max-budget-usd -1 x;   assert_config_error --max-budget-usd
}

test_effort_variable_names_for_unusual_models() {
  ZCO_EFFORT_OPUS_1M_=high zt_settings 'opus[1m]' x
  assert_setting effort high ZCO_EFFORT_OPUS_1M_
  ZCO_EFFORT_CLAUDE_SONNET_4_5=low zt_settings claude-sonnet-4.5 x
  assert_setting effort low ZCO_EFFORT_CLAUDE_SONNET_4_5
}

# ------------------------------------------------------------------ precedence

# @scenario configuration: Project beats user
test_project_beats_user() {
  zt_user_config $'[opus]\neffort = medium'
  zt_write ~/proj/.zco.config 'effort = low'
  cd ~/proj
  zt_settings opus summarize
  assert_setting effort low '~/proj/.zco.config:1'
}

# @scenario configuration: Environment beats files
test_environment_beats_files() {
  zt_write ~/proj/.zco.config 'permission_mode = acceptEdits'
  cd ~/proj
  ZCO_PERMISSION_MODE=plan zt_settings opus summarize
  assert_setting permission_mode plan ZCO_PERMISSION_MODE
}

# @scenario configuration: Command line beats everything
test_command_line_beats_everything() {
  zt_user_config $'effort = low\n[opus]\neffort = medium'
  zt_write ~/proj/.zco.config $'effort = high\n[opus]\neffort = xhigh'
  cd ~/proj
  ZCO_EFFORT=low ZCO_EFFORT_OPUS=medium zt_settings opus max summarize
  assert_setting effort max 'command line'
}

test_all_seven_layers_in_order() {
  zt_user_config $'effort = low\n[opus]\neffort = medium'
  zt_write ~/proj/.zco.config $'effort = high\n[opus]\neffort = xhigh'
  cd ~/proj
  ZCO_EFFORT=low ZCO_EFFORT_OPUS=max zt_settings opus x;  assert_setting effort max ZCO_EFFORT_OPUS
  ZCO_EFFORT=low zt_settings opus x;                      assert_setting effort low ZCO_EFFORT
  zt_settings opus x;                                     assert_setting effort xhigh '~/proj/.zco.config:3'
  zt_settings sonnet x;                                   assert_setting effort high '~/proj/.zco.config:1'
  rm ~/proj/.zco.config
  zt_settings opus x;                                     assert_setting effort medium '~/.zco.config:3'
  zt_settings sonnet x;                                   assert_setting effort low '~/.zco.config:1'
  rm ~/.zco.config
  zt_settings sonnet x;                                   assert_setting effort '' built-in
}

test_dry_run_wins_for_permission_mode() {
  ZCO_PERMISSION_MODE=acceptEdits zt_settings opus -n --permission-mode auto x
  assert_setting permission_mode plan 'command line'
}

test_mcp_flag_and_booleans() {
  zt_user_config 'mcp = Yes'
  zt_settings opus x
  assert_setting mcp true '~/.zco.config:1'
  ZCO_MCP=FALSE zt_settings opus x
  assert_setting mcp false ZCO_MCP
  ZCO_MCP=0 zt_settings opus -m x
  assert_setting mcp true 'command line'
}

# @scenario configuration: Editing a file between runs
test_editing_a_file_between_runs() {
  zt_mkdir_cd ~/proj
  zt_write ~/proj/.zco.config 'agent = reviewer'
  zt_settings opus summarize
  assert_setting effort ''
  print -r -- 'effort = high' >> ~/proj/.zco.config
  zt_settings opus summarize
  assert_setting effort high '~/proj/.zco.config:2'
}

# ------------------------------------------------------------------ lists

# @scenario configuration: Repeated list lines
test_repeated_list_lines() {
  zt_write ~/proj/.zco.config $'allowed_tools = Bash(git *)\nallowed_tools = Edit'
  cd ~/proj
  zt_settings opus x
  zt_list "$S[allowed_tools]"
  assert_eq "${(j:|:)reply}" 'Bash(git *)|Edit'
  zt_list "$Ssrc[allowed_tools]"
  assert_eq "${(j:|:)reply}" '~/proj/.zco.config:1|~/proj/.zco.config:2'
}

# @scenario configuration: Project list replaces user list
test_project_list_replaces_user_list() {
  zt_user_config 'add_dir = ~/notes'
  zt_write ~/proj/.zco.config 'add_dir = ../shared-lib'
  cd ~/proj
  zt_settings opus x
  zt_list "$S[add_dir]"
  assert_eq "${(j:|:)reply}" "$HOME/shared-lib"
}

# @scenario configuration: Command line appends
test_command_line_appends() {
  zt_write ~/proj/.zco.config 'add_dir = ../shared-lib'
  cd ~/proj
  zt_settings opus --add-dir /tmp/data summarize
  zt_list "$S[add_dir]"
  assert_eq "${(j:|:)reply}" "$HOME/shared-lib|/tmp/data"
  zt_list "$Ssrc[add_dir]"
  assert_eq "${(j:|:)reply}" "~/proj/.zco.config:1|command line"
}

test_empty_list_line_clears_the_list() {
  zt_user_config $'allowed_tools = Edit\nallowed_tools ='
  zt_settings opus x
  assert_setting allowed_tools ''
  zt_list "$Ssrc[allowed_tools]"; assert_eq "${(j:|:)reply}" '~/.zco.config:2'
  zt_user_config $'allowed_tools = Edit\nallowed_tools =\nallowed_tools = Read'
  zt_settings opus x
  zt_list "$S[allowed_tools]"; assert_eq "${(j:|:)reply}" Read
  zt_list "$Ssrc[allowed_tools]"; assert_eq "${(j:|:)reply}" '~/.zco.config:3'
  zt_user_config 'allowed_tools = Edit'
  zt_write ~/proj/.zco.config 'allowed_tools ='
  cd ~/proj
  zt_settings opus x
  assert_setting allowed_tools ''
  zt_list "$Ssrc[allowed_tools]"; assert_eq "${(j:|:)reply}" '~/proj/.zco.config:1'
}

test_list_in_a_model_section_replaces_the_file_list() {
  zt_user_config $'add_dir = /a\n[opus]\nadd_dir = /b'
  zt_settings opus x
  zt_list "$S[add_dir]"; assert_eq "${(j:|:)reply}" /b
  zt_settings haiku x
  zt_list "$S[add_dir]"; assert_eq "${(j:|:)reply}" /a
}

# ------------------------------------------------------------------ paths

# @scenario configuration: Prompt file next to the project config
test_prompt_file_next_to_the_project_config() {
  zt_write ~/proj/.zco.config 'append_system_prompt_file = prompts/style.md'
  zt_mkdir_cd ~/proj/src
  zt_settings opus summarize
  assert_setting append_system_prompt_file "$HOME/proj/prompts/style.md"
}

test_tilde_and_absolute_paths_in_files() {
  zt_user_config $'add_dir = ~/notes\nadd_dir = /abs/dir\nsettings = conf/s.json\nmcp_config = ~/m.json'
  zt_settings opus x
  zt_list "$S[add_dir]"; assert_eq "${(j:|:)reply}" "$HOME/notes|/abs/dir"
  assert_setting settings "$HOME/conf/s.json"
  zt_list "$S[mcp_config]"; assert_eq "${(j:|:)reply}" "$HOME/m.json"
}

test_settings_json_is_not_a_path() {
  zt_user_config 'settings = {"model": "x"}'
  zt_settings opus x
  assert_setting settings '{"model": "x"}'
}

test_command_line_and_environment_paths_stay_relative() {
  ZCO_SYSTEM_PROMPT_FILE=p/s.md zt_settings opus --add-dir ../lib x
  assert_setting system_prompt_file p/s.md ZCO_SYSTEM_PROMPT_FILE
  zt_list "$S[add_dir]"; assert_eq "${(j:|:)reply}" ../lib
}

# ------------------------------------------------------------------ validation

# @scenario configuration: Unknown key
test_unknown_key() {
  zt_user_config $'effort = low\n# a comment\nefort = high'
  zt_settings opus summarize
  assert_config_error '~/.zco.config:3' efort
}

# @scenario configuration: Invalid value
test_invalid_value() {
  zt_write ~/proj/.zco.config $'agent = x\nmax_turns = many'
  cd ~/proj
  zt_settings opus x
  assert_config_error '~/proj/.zco.config:2' max_turns
}

test_invalid_values_by_type() {
  local bad
  for bad in 'effort = turbo' 'effort = ultracode' 'mcp = maybe' 'session_persistence = 2' \
             'max_budget_usd = $1' 'max_budget_usd = 1.2.3' 'max_turns = 0' 'max_turns = -3'; do
    zt_user_config $bad
    zt_settings opus x
    assert_config_error '~/.zco.config:1' "${bad%% *}"
  done
}

# @scenario configuration: Project file sets the Claude command
test_project_file_sets_the_claude_command() {
  zt_write ~/clone/.zco.config 'claude_cmd = ./run-me.sh'
  cd ~/clone
  zt_settings opus summarize
  assert_config_error claude_cmd 'only allowed in the user file' '~/clone/.zco.config:1'
}

test_every_restricted_key_is_refused_in_a_project_file() {
  local k
  cd ~ && mkdir -p proj && cd proj
  for k in claude_cmd extra_args mcp_config settings models prefix raw_line; do
    zt_write ~/proj/.zco.config "$k = x"
    zt_settings opus x
    assert_config_error "$k" 'only allowed in the user file'
  done
}

# @scenario configuration: Project file asks for bypassPermissions
test_project_file_asks_for_bypass_permissions() {
  zt_write ~/proj/.zco.config 'permission_mode = bypassPermissions'
  cd ~/proj
  zt_settings opus x
  assert_config_error permission_mode '~/proj/.zco.config:1'
}

test_user_file_may_set_restricted_keys() {
  zt_user_config $'permission_mode = bypassPermissions\nclaude_cmd = claude-work\nextra_args = --name\n[haiku]\nclaude_cmd = claude-fast'
  zt_settings opus x
  assert_eq $ZT_RC 0 "$REPLY"
  assert_setting permission_mode bypassPermissions
  assert_setting claude_cmd claude-work
  zt_settings haiku x
  assert_setting claude_cmd claude-fast
}

test_unreadable_user_file_is_an_error() {
  zt_user_config 'effort = low'
  chmod 000 ~/.zco.config
  [[ -r ~/.zco.config ]] && zt_skip "running as a user who can read anything"
  zt_settings opus x
  assert_config_error '~/.zco.config'
}

# ------------------------------------------------------------------ system prompt groups

test_command_line_text_beats_a_configured_file() {
  zt_user_config 'append_system_prompt_file = ~/terse.md'
  zt_settings opus --append-system-prompt 'Reply in French.' x
  assert_setting append_system_prompt 'Reply in French.' 'command line'
  assert_setting append_system_prompt_file ''
}

test_both_forms_in_one_layer_is_an_error() {
  zt_settings opus --system-prompt x --system-prompt-file p.md x
  assert_config_error --system-prompt --system-prompt-file
  zt_user_config $'append_system_prompt = a\nappend_system_prompt_file = b.md'
  zt_settings opus x
  assert_config_error append_system_prompt append_system_prompt_file '~/.zco.config'
  ZCO_SYSTEM_PROMPT=a ZCO_SYSTEM_PROMPT_FILE=b zt_settings opus x
  assert_config_error ZCO_SYSTEM_PROMPT ZCO_SYSTEM_PROMPT_FILE
}

test_forms_in_different_layers_highest_wins() {
  zt_user_config $'system_prompt = from user\n[opus]\nsystem_prompt_file = opus.md'
  zt_settings opus x
  assert_setting system_prompt_file "$HOME/opus.md" '~/.zco.config:3'
  assert_setting system_prompt ''
  zt_settings sonnet x
  assert_setting system_prompt 'from user'
  assert_setting system_prompt_file ''
}

# ------------------------------------------------------------------ review follow-ups

test_home_with_pattern_characters_is_still_not_a_project_file() {
  export HOME="$ZT_TMP/home (work) [x]"
  mkdir -p "$HOME/sub" && cd "$HOME/sub"
  zt_user_config $'claude_cmd = claude\nmodels = opus'
  zt_settings opus x
  assert_eq $ZT_RC 0 "$REPLY"
  assert_eq "$zco_files[2]" '' "the user file must not also be read as the project file"
}

test_empty_variables_count_as_unset() {
  zt_user_config $'effort = low\npermission_mode = acceptEdits'
  ZCO_EFFORT=high ZCO_EFFORT_OPUS= zt_settings opus x
  assert_setting effort high ZCO_EFFORT
  ZCO_EFFORT= ZCO_PERMISSION_MODE= zt_settings opus x
  assert_setting effort low '~/.zco.config:1'
  assert_setting permission_mode acceptEdits
}

test_empty_local_config_switch_counts_as_unset() {
  zt_write ~/proj/.zco.config 'agent = rev'
  cd ~/proj
  ZCO_LOCAL_CONFIG= zt_settings opus x
  assert_eq $ZT_RC 0 "$REPLY"
  assert_eq "$zco_files[2]" "$HOME/proj/.zco.config"
}

test_control_characters_in_a_file_are_refused() {
  zt_mkdir_cd ~/repo/deep
  print -rn -- $'permission_mode = bypassPermissions\0\n' > ~/repo/.zco.config
  zt_settings opus x
  assert_config_error '~/repo/.zco.config:1' 'control character'
  print -rn -- $'append_system_prompt = --safe-mode\0\n' > ~/repo/.zco.config
  zt_settings opus x
  assert_config_error '~/repo/.zco.config:1'
  print -rn -- $'agent = rev\e[8m\n' > ~/repo/.zco.config
  zt_settings opus x
  assert_config_error '~/repo/.zco.config:1' 'control character'
  print -rn -- $'ag\e]52;c;eA==\aent = x\n' > ~/repo/.zco.config
  zt_settings opus x
  assert_config_error 'control character'
  assert_not_contains "$REPLY" $'\e' "the message must not echo the escape sequence"
  print -rn -- $'agent = a\tb\r\n' > ~/repo/.zco.config
  zt_settings opus x
  assert_eq $ZT_RC 0 "tabs and CRLF line ends are fine: $REPLY"
}
