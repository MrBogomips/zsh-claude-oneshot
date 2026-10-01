# Spec Delta

## Purpose

Exposes the Claude Code options commonly needed for one-shot runs as zco options and configuration keys: agent, skill, system prompts, extra directories, tool rules, settings, MCP configuration, fallback model, turn limit and resume. Any other Claude Code flag can be passed through a filtered escape hatch.

## ADDED Requirements

### Requirement: Agent
`-a NAME`, `--agent NAME` and the `agent` setting SHALL pass `--agent NAME` to Claude Code.

#### Scenario: Agent from the command line
- **WHEN** the user runs `opus -a reviewer review the staged changes`
- **THEN** Claude Code receives `--agent reviewer` and the prompt `review the staged changes`

#### Scenario: Agent from the project file
- **WHEN** the project file sets `agent = reviewer` and the user runs `opus review the staged changes`
- **THEN** Claude Code receives `--agent reviewer`

### Requirement: Skill
`-s NAME` and `--skill NAME` SHALL make the prompt start with `/NAME`. When a prompt is also given, it follows after a single space. A leading `/` in NAME SHALL be accepted and not doubled. NAME SHALL match `[A-Za-z0-9][A-Za-z0-9:._-]*` (after removing a leading `/`); otherwise the command fails with a usage error.

A skill alone SHALL satisfy the rule that a run needs a prompt or input. The skill SHALL NOT be settable from configuration files or the environment.

#### Scenario: Skill without prompt
- **WHEN** the user runs `haiku -s prepare-commit`
- **THEN** Claude Code receives the prompt `/prepare-commit`

#### Scenario: Skill with prompt
- **WHEN** the user runs `sonnet --skill /review focus on the tests`
- **THEN** Claude Code receives the prompt `/review focus on the tests`

#### Scenario: Invalid skill name
- **WHEN** the user runs `opus -s 'bad name' go`
- **THEN** a usage error naming the skill is printed and Claude Code is not run

### Requirement: System prompts
The following options and settings SHALL pass the Claude Code flag of the same name:
- `--system-prompt TEXT` / `system_prompt`
- `--system-prompt-file PATH` / `system_prompt_file`
- `--append-system-prompt TEXT` / `append_system_prompt`
- `--append-system-prompt-file PATH` / `append_system_prompt_file`

The text form and the file form of the same prompt count as one setting. The highest layer that sets either form wins, and at most one of the two flags SHALL be passed. Giving both forms of the same prompt in one layer SHALL be a usage error. A prompt file that does not exist or cannot be read SHALL be a usage error naming the file.

#### Scenario: Command line text beats a configured file
- **WHEN** the user file sets `append_system_prompt_file = ~/.config/zco/terse.md` and the user runs `opus --append-system-prompt 'Reply in French.' summarize`
- **THEN** Claude Code receives `--append-system-prompt "Reply in French."` and no `--append-system-prompt-file`

#### Scenario: Both forms on the command line
- **WHEN** the user runs `opus --system-prompt x --system-prompt-file p.md summarize`
- **THEN** a usage error is printed and Claude Code is not run

#### Scenario: Missing prompt file
- **WHEN** the project file sets `system_prompt_file = missing.md` and that file does not exist
- **THEN** a usage error naming the resolved path is printed and Claude Code is not run

### Requirement: Directories and tool rules
The options `--add-dir DIR`, `--allowed-tools RULE` and `--disallowed-tools RULE` MAY be repeated. So may the list settings `add_dir`, `allowed_tools` and `disallowed_tools`. Each value in the effective list SHALL be passed as its own flag and value pair, in list order.

#### Scenario: Two tool rules
- **WHEN** the project file contains `allowed_tools = Bash(git *)` and `allowed_tools = Edit`
- **THEN** Claude Code receives `--allowed-tools "Bash(git *)" --allowed-tools Edit`

#### Scenario: Directory from the command line
- **WHEN** the user runs `opus --add-dir ../shared-lib compare the two parsers`
- **THEN** Claude Code receives `--add-dir ../shared-lib` and the prompt `compare the two parsers`

### Requirement: Settings, MCP configuration, fallback model and turn limit
The following options and settings SHALL pass the Claude Code flag of the same name:
- `--settings VALUE` / `settings`, user file only
- `--mcp-config PATH`, repeatable / `mcp_config`, user file only
- `--fallback-model MODEL` / `fallback_model`
- `--max-turns N` / `max_turns`

N SHALL be a positive integer; otherwise the command fails with a usage error. When MCP configuration files are given and MCP servers are not otherwise included, `--strict-mcp-config` SHALL still be passed, so that only the named servers load.

#### Scenario: Only the named MCP servers
- **WHEN** the user runs `opus --mcp-config ./gh.json check the open issues`
- **THEN** Claude Code receives `--mcp-config ./gh.json` and `--strict-mcp-config`

#### Scenario: Named servers plus the configured ones
- **WHEN** the user runs `opus -m --mcp-config ./gh.json check the open issues`
- **THEN** Claude Code receives `--mcp-config ./gh.json` and no `--strict-mcp-config`

#### Scenario: Invalid turn limit
- **WHEN** the user runs `opus --max-turns 0 summarize`
- **THEN** a usage error naming `--max-turns` is printed and Claude Code is not run

### Requirement: Permission mode option
`--permission-mode MODE` SHALL set the permission mode for the run and override configuration files and the environment. `-n` SHALL still select `plan` when both are given.

#### Scenario: Permission mode for one run
- **WHEN** the project file sets `permission_mode = acceptEdits` and the user runs `opus --permission-mode auto commit local changes`
- **THEN** Claude Code receives `--permission-mode auto`

### Requirement: Resume a session
`-r ID` and `--resume ID` SHALL pass `--resume ID` to Claude Code. ID is required. Combining it with `-c` SHALL be a usage error.

#### Scenario: Resume by id
- **WHEN** the user runs `opus -r 3f2a9c1e-0000-4000-8000-000000000000 go ahead`
- **THEN** Claude Code receives `--resume 3f2a9c1e-0000-4000-8000-000000000000` and no `--continue`

#### Scenario: Resume and continue together
- **WHEN** the user runs `opus -c -r abc go ahead`
- **THEN** a usage error is printed and Claude Code is not run

### Requirement: Extra arguments
Each line of the `extra_args` list, set in the user file only, SHALL be passed to Claude Code as one argument, after the options above. A usage error naming the argument SHALL be raised, and Claude Code SHALL NOT be run, when an extra argument is any of the following, as a plain flag or in `--flag=value` form:
- a flag the plugin never passes (see claude-invocation);
- a flag the plugin manages itself: `-p`, `--print`, `--model`, `--permission-mode`, `--effort`, `--output-format`, `--input-format`, `--verbose`, `--continue`, `-c`, `--resume`, `-r`, `--strict-mcp-config`, `--no-session-persistence`, `--max-budget-usd`, or any flag listed in this capability.

#### Scenario: Flag without a first-class option
- **WHEN** the user file contains `extra_args = --name` and `extra_args = nightly-summary`
- **THEN** Claude Code receives `--name nightly-summary` after the curated options

#### Scenario: Forbidden flag in extra arguments
- **WHEN** the user file contains `extra_args = --dangerously-skip-permissions`
- **THEN** a usage error naming that flag is printed and Claude Code is not run

#### Scenario: Managed flag in extra arguments
- **WHEN** the user file contains `extra_args = --model=opus`
- **THEN** a usage error naming `--model` is printed and Claude Code is not run
