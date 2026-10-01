# Spec Delta

## Purpose

Defines the exact Claude Code command line, input and exit status used for each one-shot run, so runs are predictable, fast to start and keep the user's CLAUDE.md, hooks and permission rules in force.

## ADDED Requirements

### Requirement: Configurable Claude Code command
The command SHALL come from `ZCO_CLAUDE_CMD`, or else from `claude_cmd` in the user configuration file, with default `claude`. If `ZCO_CLAUDE_CMD` is an array, its elements are the command words. If it is a string, or comes from the file, it SHALL be split into words the way zsh splits a command line, honouring quotes. Quotes are then removed, and no parameter expansion, command substitution or evaluation takes place.

The first word MAY name an external command or a shell function. The command SHALL run in the current shell, so functions work. If the first word is an alias, the run SHALL fail with an error suggesting a function instead. If it is not found, the run SHALL fail with an error naming it and exit status 127.

#### Scenario: Default command
- **WHEN** `ZCO_CLAUDE_CMD` is unset and the user runs `opus commit local changes`
- **THEN** the external `claude` command is run

#### Scenario: Wrapper function
- **WHEN** a function `claude-work` exists, `ZCO_CLAUDE_CMD=claude-work` is set and the user runs `opus commit local changes`
- **THEN** `claude-work` is called with the Claude Code arguments

#### Scenario: Multi-word command with quoted value
- **WHEN** `ZCO_CLAUDE_CMD="env CLAUDE_CONFIG_DIR='/tmp/cfg dir' claude"` is set
- **THEN** `claude` runs with environment variable `CLAUDE_CONFIG_DIR` equal to `/tmp/cfg dir`

#### Scenario: No evaluation of the setting
- **WHEN** `ZCO_CLAUDE_CMD='claude $(touch /tmp/pwned)'` is set
- **THEN** no command substitution runs and `/tmp/pwned` is not created

#### Scenario: Command from the user file
- **WHEN** `ZCO_CLAUDE_CMD` is unset and the user file contains `claude_cmd = claude-work`
- **THEN** `claude-work` is called with the Claude Code arguments

#### Scenario: Command not found
- **WHEN** `ZCO_CLAUDE_CMD=no-such-claude` is set
- **THEN** an error naming `no-such-claude` is printed on stderr and the exit status is 127

#### Scenario: Alias as command
- **WHEN** `ZCO_CLAUDE_CMD` names an alias
- **THEN** an error suggesting a function instead is printed on stderr and Claude Code is not run

### Requirement: Argument order
Claude Code SHALL receive these arguments in this order, with each optional argument present only when its rule applies (the options from 3 to 13 are defined in claude-options):
1. `-p --model <model> --permission-mode <mode>`
2. `--effort <level>`
3. `--agent <name>`
4. `--system-prompt <text>` or `--system-prompt-file <path>`
5. `--append-system-prompt <text>` or `--append-system-prompt-file <path>`
6. `--add-dir <dir>`, once per directory
7. `--allowed-tools <rule>`, once per rule
8. `--disallowed-tools <rule>`, once per rule
9. `--settings <value>`
10. `--mcp-config <path>`, once per file
11. `--strict-mcp-config`
12. `--fallback-model <model>`
13. `--max-turns <n>`
14. `--continue` or `--resume <id>`
15. `--no-session-persistence`
16. `--max-budget-usd <amount>`
17. the `extra_args` arguments, in list order
18. `--output-format stream-json --verbose`
19. `--` followed by the prompt as one argument, when there is a prompt

The model SHALL be passed exactly as named by the command or `zco`. The plugin SHALL NOT remap model names; Claude Code's own alias resolution applies, including `ANTHROPIC_DEFAULT_*_MODEL`.

#### Scenario: Defaults with stderr not a terminal
- **WHEN** no `ZCO_` variables are set, no configuration file exists, stderr is not a terminal and the user runs `opus commit local changes`
- **THEN** Claude Code receives exactly `-p --model opus --permission-mode auto --strict-mcp-config -- "commit local changes"`

#### Scenario: Everything turned on
- **WHEN** `jq` is available, `ZCO_SESSION_PERSISTENCE=0` and `ZCO_MAX_BUDGET_USD=0.50` are set, no configuration file exists, stderr is not a terminal and the user runs `opus -v -m -c xhigh go ahead`
- **THEN** Claude Code receives exactly `-p --model opus --permission-mode auto --effort xhigh --continue --no-session-persistence --max-budget-usd 0.50 --output-format stream-json --verbose -- "go ahead"`

#### Scenario: Options from files and command line in order
- **WHEN** `~/proj/.zco.config` sets `agent = reviewer` and `add_dir = lib`, there is no user file, stderr is not a terminal, and the user runs `opus --append-system-prompt 'Be terse.' --max-turns 5 summarize` in `~/proj`
- **THEN** Claude Code receives exactly `-p --model opus --permission-mode auto --agent reviewer --append-system-prompt "Be terse." --add-dir <home>/proj/lib --strict-mcp-config --max-turns 5 -- summarize`, where `<home>` is the absolute home directory

#### Scenario: Model remapping left to Claude Code
- **WHEN** `ANTHROPIC_DEFAULT_OPUS_MODEL` is set and the user runs `opus summarize`
- **THEN** Claude Code receives `--model opus` and the variable is passed through unchanged

### Requirement: Permission mode
The permission mode SHALL be the effective value of the `permission_mode` setting, following the configuration precedence (files, `ZCO_PERMISSION_MODE`, `--permission-mode`). The default is `auto`. `-n` SHALL select `plan` regardless of every other source. The value SHALL be passed through without validation, so Claude Code decides which modes exist. The one exception is the project-file restriction on `bypassPermissions` (see configuration).

#### Scenario: Default mode
- **WHEN** `ZCO_PERMISSION_MODE` is unset and the user runs `opus commit local changes`
- **THEN** Claude Code receives `--permission-mode auto`

#### Scenario: Configured mode
- **WHEN** `ZCO_PERMISSION_MODE=acceptEdits` and the user runs `sonnet edit README.md: add an install section`
- **THEN** Claude Code receives `--permission-mode acceptEdits`

#### Scenario: Dry run wins
- **WHEN** `ZCO_PERMISSION_MODE=acceptEdits` and the user runs `haiku -n reorg this folder by year`
- **THEN** Claude Code receives `--permission-mode plan`

### Requirement: Effort resolution
The effort SHALL be the effective value of the `effort` setting, following the configuration precedence. The sources, from highest to lowest, are:
1. The command line (effort word or `-e`).
2. `ZCO_EFFORT_<MODEL>`. `<MODEL>` is the model name in upper case, with every character other than `A-Z`, `0-9` and `_` replaced by `_`.
3. `ZCO_EFFORT`.
4. The project file's model section, then the project file outside sections.
5. The user file's model section, then the user file outside sections.
6. Nothing.

`--effort` SHALL be passed only when an effort was resolved. Otherwise Claude Code's own effort settings apply. An effort from a variable or file that is not one of the five effort words SHALL be a usage error naming the variable, or the file and line.

#### Scenario: No effort anywhere
- **WHEN** no effort is given and neither variable is set
- **THEN** Claude Code receives no `--effort` argument

#### Scenario: Model-specific variable beats the global one
- **WHEN** `ZCO_EFFORT=low` and `ZCO_EFFORT_OPUS=max` are set
- **THEN** `opus summarize` passes `--effort max` and `sonnet summarize` passes `--effort low`

#### Scenario: Command line beats variables
- **WHEN** `ZCO_EFFORT_OPUS=max` is set and the user runs `opus medium summarize`
- **THEN** Claude Code receives `--effort medium`

#### Scenario: Invalid variable value
- **WHEN** `ZCO_EFFORT=turbo` is set and the user runs `opus summarize`
- **THEN** a usage error naming `ZCO_EFFORT` is printed and Claude Code is not run

### Requirement: No effort for haiku
A model whose name contains `haiku` (any case) SHALL NOT receive `--effort`. One notice line SHALL be printed on stderr, unless `-q` is given, when the dropped effort came from a source meant for this model: the command line, `ZCO_EFFORT_<MODEL>`, or a model section of a configuration file. An effort from a source that applies to all models (`ZCO_EFFORT`, or a file entry outside sections) SHALL be dropped silently.

#### Scenario: Effort word with haiku
- **WHEN** the user runs `haiku xhigh summarize`
- **THEN** Claude Code receives no `--effort`, and one notice saying haiku does not support effort is printed on stderr

#### Scenario: Global effort with haiku
- **WHEN** `ZCO_EFFORT=high` is set, or the user file sets `effort = high` outside sections, and the user runs `haiku summarize`
- **THEN** Claude Code receives no `--effort` and no notice is printed

#### Scenario: Haiku section with effort
- **WHEN** the user file has a section `[haiku]` with `effort = low` and the user runs `haiku summarize`
- **THEN** Claude Code receives no `--effort`, and one notice naming the file and line is printed on stderr

### Requirement: MCP servers skipped by default
`--strict-mcp-config` SHALL be passed, unless `-m` is given or the effective `mcp` setting (`ZCO_MCP` or a configuration file) is true. With this flag, only the servers named with `--mcp-config` are loaded (see claude-options); without either, none are.

#### Scenario: MCP requested
- **WHEN** the user runs `opus -m check the open issues`
- **THEN** Claude Code does not receive `--strict-mcp-config`

#### Scenario: MCP enabled by variable
- **WHEN** `ZCO_MCP=1` is set and the user runs `opus check the open issues`
- **THEN** Claude Code does not receive `--strict-mcp-config`

### Requirement: Continue the last session
`-c` SHALL pass `--continue`, which continues the most recent Claude Code session in the current directory.

#### Scenario: Follow-up after a dry run
- **WHEN** the user runs `haiku -n reorg this folder by year` and then `haiku -c go ahead`
- **THEN** the second run receives `--continue`, `--permission-mode auto` and the prompt `go ahead`

### Requirement: Session persistence
Sessions SHALL be saved by default. When the effective `session_persistence` setting (`ZCO_SESSION_PERSISTENCE` or a configuration file) is false, `--no-session-persistence` SHALL be passed.

#### Scenario: Persistence turned off
- **WHEN** `ZCO_SESSION_PERSISTENCE=false` is set and the user runs `opus summarize`
- **THEN** Claude Code receives `--no-session-persistence`

#### Scenario: Persistence turned off in the user file
- **WHEN** the user file contains `session_persistence = off`
- **THEN** Claude Code receives `--no-session-persistence`

### Requirement: Budget cap
When the effective `max_budget_usd` setting is set (by `--max-budget-usd`, `ZCO_MAX_BUDGET_USD` or a configuration file), `--max-budget-usd <amount>` SHALL be passed. The amount is a non-negative decimal number. Any other value SHALL be a usage error naming its source.

#### Scenario: Budget set
- **WHEN** `ZCO_MAX_BUDGET_USD=0.25` is set
- **THEN** Claude Code receives `--max-budget-usd 0.25`

#### Scenario: Invalid budget
- **WHEN** `ZCO_MAX_BUDGET_USD=cheap` is set and the user runs `opus summarize`
- **THEN** a usage error naming `ZCO_MAX_BUDGET_USD` is printed and Claude Code is not run

### Requirement: Standard input
When the command's stdin is a pipe or a regular file, Claude Code SHALL receive it unchanged. When stdin is anything else, such as a terminal or a character device, Claude Code SHALL read its stdin from `/dev/null`. When both input and a prompt are present, both SHALL be passed.

#### Scenario: Piped input and prompt
- **WHEN** the user runs `git diff | haiku summarize for a changelog`
- **THEN** Claude Code receives the diff on stdin and the prompt `summarize for a changelog`

#### Scenario: Redirected file
- **WHEN** the user runs `haiku summarize < notes.txt`
- **THEN** Claude Code receives the contents of `notes.txt` on stdin

#### Scenario: Interactive terminal
- **WHEN** the user runs `opus commit local changes` in an interactive terminal
- **THEN** Claude Code's stdin is `/dev/null`, not the terminal

### Requirement: Flags that are never passed
The plugin SHALL NEVER pass `--bare`, `--safe-mode`, `--dangerously-skip-permissions` or `--allow-dangerously-skip-permissions`, whatever the options, variables and configuration files, including `extra_args`. The user's CLAUDE.md files, hooks and permission rules stay in force.

#### Scenario: No bypass flags under any configuration
- **WHEN** Claude Code is invoked with any combination of options, `ZCO_` variables and configuration keys
- **THEN** none of `--bare`, `--safe-mode`, `--dangerously-skip-permissions` or `--allow-dangerously-skip-permissions` is among the arguments the plugin passes

### Requirement: Exit status
The command SHALL return Claude Code's exit status. This includes runs where progress is being rendered.

#### Scenario: Failing run
- **WHEN** Claude Code exits with status 3
- **THEN** the command returns 3

#### Scenario: Failing run with live progress
- **WHEN** progress is rendered and Claude Code exits with status 1
- **THEN** the command returns 1, not the status of the progress renderer
