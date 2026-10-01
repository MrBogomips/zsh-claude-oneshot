# claude-options: the curated Claude Code options and extra_args, through zco.

zt_load

# @scenario claude-options: Agent from the command line
test_agent_from_the_command_line() {
  zt_zco opus -a reviewer review the staged changes
  assert_argv_has --agent reviewer
  assert_argv_has -- 'review the staged changes'
}

# @scenario claude-options: Agent from the project file
test_agent_from_the_project_file() {
  zt_write ~/proj/.zco.config 'agent = reviewer'
  cd ~/proj
  zt_zco opus review the staged changes
  assert_argv_has --agent reviewer
}

# @scenario claude-options: Skill without prompt
test_skill_without_prompt() {
  zt_zco haiku -s prepare-commit
  assert_argv -p --model haiku --permission-mode auto --strict-mcp-config -- /prepare-commit
}

# @scenario claude-options: Skill with prompt
test_skill_with_prompt() {
  zt_zco sonnet --skill /review focus on the tests
  assert_argv_has -- '/review focus on the tests'
}

test_plugin_skill_names() {
  zt_zco sonnet -s my-plugin:review.v2_x go
  assert_argv_has -- '/my-plugin:review.v2_x go'
}

# @scenario claude-options: Invalid skill name
test_invalid_skill_name() {
  zt_zco opus -s 'bad name' go
  assert_status 2
  assert_contains "$ZT_ERR" 'bad name'
  assert_not_run
  zt_zco opus -s //double go
  assert_status 2
  zt_zco opus -s -dash go
  assert_status 2
}

# @scenario claude-options: Command line text beats a configured file
test_command_line_text_beats_a_configured_file() {
  zt_user_config 'append_system_prompt_file = ~/.config/zco/terse.md'
  zt_zco opus --append-system-prompt 'Reply in French.' summarize
  assert_status 0
  assert_argv_has --append-system-prompt 'Reply in French.'
  assert_argv_lacks --append-system-prompt-file
}

# @scenario claude-options: Both forms on the command line
test_both_forms_on_the_command_line() {
  print -r -- x > p.md
  zt_zco opus --system-prompt x --system-prompt-file p.md summarize
  assert_status 2
  assert_not_run
}

# @scenario claude-options: Missing prompt file
test_missing_prompt_file() {
  zt_write ~/proj/.zco.config 'system_prompt_file = missing.md'
  cd ~/proj
  zt_zco opus summarize
  assert_status 2
  assert_contains "$ZT_ERR" "$HOME/proj/missing.md"
  assert_not_run
}

test_readable_prompt_file_is_passed() {
  zt_write ~/proj/prompts/style.md 'Be terse.'
  zt_write ~/proj/.zco.config 'append_system_prompt_file = prompts/style.md'
  zt_mkdir_cd ~/proj/src
  zt_zco opus summarize
  assert_status 0
  assert_argv_has --append-system-prompt-file $HOME/proj/prompts/style.md
}

# @scenario claude-options: Two tool rules
test_two_tool_rules() {
  zt_write ~/proj/.zco.config $'allowed_tools = Bash(git *)\nallowed_tools = Edit'
  cd ~/proj
  zt_zco opus x
  assert_argv_has --allowed-tools 'Bash(git *)' --allowed-tools Edit
}

# @scenario claude-options: Directory from the command line
test_directory_from_the_command_line() {
  zt_zco opus --add-dir ../shared-lib compare the two parsers
  assert_argv_has --add-dir ../shared-lib
  assert_argv_has -- 'compare the two parsers'
}

# @scenario claude-options: Only the named MCP servers
test_only_the_named_mcp_servers() {
  zt_zco opus --mcp-config ./gh.json check the open issues
  assert_argv_has --mcp-config ./gh.json --strict-mcp-config
}

# @scenario claude-options: Named servers plus the configured ones
test_named_servers_plus_the_configured_ones() {
  zt_zco opus -m --mcp-config ./gh.json check the open issues
  assert_argv_has --mcp-config ./gh.json
  assert_argv_lacks --strict-mcp-config
}

# @scenario claude-options: Invalid turn limit
test_invalid_turn_limit() {
  zt_zco opus --max-turns 0 summarize
  assert_status 2
  assert_contains "$ZT_ERR" --max-turns
  assert_not_run
}

test_settings_and_fallback_model() {
  zt_zco opus --settings '{"x":1}' --fallback-model sonnet go
  assert_argv_has --settings '{"x":1}'
  assert_argv_has --fallback-model sonnet
}

# @scenario claude-options: Permission mode for one run
test_permission_mode_for_one_run() {
  zt_write ~/proj/.zco.config 'permission_mode = acceptEdits'
  cd ~/proj
  zt_zco opus --permission-mode auto commit local changes
  assert_argv_has --permission-mode auto
}

# @scenario claude-options: Resume by id
test_resume_by_id() {
  zt_zco opus -r 3f2a9c1e-0000-4000-8000-000000000000 go ahead
  assert_argv_has --resume 3f2a9c1e-0000-4000-8000-000000000000
  assert_argv_lacks --continue
}

# @scenario claude-options: Resume and continue together
test_resume_and_continue_together() {
  zt_zco opus -c -r abc go ahead
  assert_status 2
  assert_not_run
}

# @scenario claude-options: Flag without a first-class option
test_flag_without_a_first_class_option() {
  zt_user_config $'extra_args = --name\nextra_args = nightly-summary'
  zt_zco opus --max-turns 2 summarize
  assert_argv -p --model opus --permission-mode auto --strict-mcp-config --max-turns 2 \
    --name nightly-summary -- summarize
}

# @scenario claude-options: Forbidden flag in extra arguments
test_forbidden_flag_in_extra_arguments() {
  zt_user_config 'extra_args = --dangerously-skip-permissions'
  zt_zco opus summarize
  assert_status 2
  assert_contains "$ZT_ERR" --dangerously-skip-permissions
  assert_not_run
}

# @scenario claude-options: Managed flag in extra arguments
test_managed_flag_in_extra_arguments() {
  zt_user_config 'extra_args = --model=opus'
  zt_zco opus summarize
  assert_status 2
  assert_contains "$ZT_ERR" --model
  assert_not_run
}

test_forbidden_flag_as_an_option_value_is_refused() {
  zt_zco opus --agent --bare summarize
  assert_status 2
  assert_contains "$ZT_ERR" --bare
  assert_not_run
}

test_forbidden_flag_in_the_prompt_is_just_text() {
  zt_zco opus -- --dangerously-skip-permissions is a flag I want explained
  assert_status 0
  assert_argv_has -- '--dangerously-skip-permissions is a flag I want explained'
}
