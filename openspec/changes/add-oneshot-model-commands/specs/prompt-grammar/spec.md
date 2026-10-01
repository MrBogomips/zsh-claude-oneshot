# Spec Delta

## Purpose

Defines how the words after a model command are split into an optional effort level, options and the prompt: `<model> [effort] [flags] [--] prompt…`.

## ADDED Requirements

### Requirement: Leading tokens and prompt start
Leading arguments SHALL be consumed while they are recognised options (together with their values) or an effort word. The first other argument SHALL start the prompt. The prompt SHALL be that argument and all following arguments, joined with single spaces. Options and the effort word MAY appear in any order before the prompt.

#### Scenario: Prompt only
- **WHEN** the user runs `opus commit local changes`
- **THEN** no effort is set and the prompt is `commit local changes`

#### Scenario: Effort word first
- **WHEN** the user runs `opus xhigh commit local changes`
- **THEN** the effort is `xhigh` and the prompt is `commit local changes`

#### Scenario: Options and effort in either order
- **WHEN** the user runs `opus -n high reorg this folder` or `opus high -n reorg this folder`
- **THEN** in both cases dry run is on, the effort is `high` and the prompt is `reorg this folder`

#### Scenario: Options after the prompt start are prompt text
- **WHEN** the user runs `opus explain what -n does in grep`
- **THEN** dry run is off and the prompt is `explain what -n does in grep`

### Requirement: Bare effort word
A bare effort word SHALL be exactly one of `low`, `medium`, `high`, `xhigh`, `max` in lower case. A bare effort word SHALL be taken as the effort only while no effort has been set in the same command. Otherwise it starts the prompt.

#### Scenario: Effort word repeated as prompt text
- **WHEN** the user runs `opus high high level overview`
- **THEN** the effort is `high` and the prompt is `high level overview`

#### Scenario: Capitalised word is prompt text
- **WHEN** the user runs `opus High level overview`
- **THEN** no effort is set and the prompt is `High level overview`

#### Scenario: Effort already set by option
- **WHEN** the user runs `opus -e max high level overview`
- **THEN** the effort is `max` and the prompt is `high level overview`

### Requirement: Effort option
`-e LEVEL`, `--effort LEVEL` and `--effort=LEVEL` SHALL set the effort. LEVEL is one of the five effort words. It replaces any effort set earlier in the same command. An unknown LEVEL, or a missing LEVEL, SHALL be a usage error that lists the valid levels.

#### Scenario: Long form with equals
- **WHEN** the user runs `sonnet --effort=low fix the typo`
- **THEN** the effort is `low` and the prompt is `fix the typo`

#### Scenario: Unknown level
- **WHEN** the user runs `opus -e extreme do it`
- **THEN** a usage error listing `low medium high xhigh max` is printed and Claude Code is not run

### Requirement: ultracode is refused
`ultracode` SHALL NOT be accepted as an effort level. Without a preceding `--`, the command SHALL fail with a usage error in both of these cases:
- `ultracode` is given as the `-e` level.
- `ultracode` is the first word of the prompt.

The error explains that ultracode is not supported for one-shot runs and that `--` sends it as prompt text.

#### Scenario: Bare ultracode
- **WHEN** the user runs `opus ultracode refactor the parser`
- **THEN** a usage error mentioning `ultracode` and `--` is printed, the exit status is 2 and Claude Code is not run

#### Scenario: ultracode after an effort word
- **WHEN** the user runs `opus high ultracode refactor the parser`
- **THEN** a usage error mentioning `ultracode` is printed and Claude Code is not run

#### Scenario: ultracode after the separator
- **WHEN** the user runs `opus -- ultracode refactor the parser`
- **THEN** Claude Code runs with the prompt `ultracode refactor the parser` and no effort

### Requirement: End of options
The argument `--` SHALL end option and effort parsing. It is not part of the prompt. Every following argument SHALL be prompt text, including arguments that look like options or effort words.

#### Scenario: Effort word as prompt text
- **WHEN** the user runs `opus -- high level overview of this repo`
- **THEN** no effort is set and the prompt is `high level overview of this repo`

#### Scenario: Prompt starting with a dash
- **WHEN** the user runs `opus -- -v prints nothing, why?`
- **THEN** the prompt is `-v prints nothing, why?`

### Requirement: Options
The following options SHALL be recognised before the prompt.

Options without a value:
- `-n` / `--dry-run`: plan permission mode, so nothing is changed.
- `-c` / `--continue`: continue the most recent session in the current directory.
- `-m` / `--mcp`: include MCP servers.
- `-v` / `--verbose`: more progress output.
- `-q` / `--quiet`: less output.
- `-h` / `--help`: print usage.
- `--show-config`: print the effective configuration (see configuration).
- `--shell`, `--literal`: choose how the interactive line is rewritten (see raw-line-capture). They have no effect when the command runs, and are accepted without error.

Options with a value (behaviour in claude-options and claude-invocation):
- `-e` / `--effort LEVEL`
- `-a` / `--agent NAME`
- `-s` / `--skill NAME`
- `-r` / `--resume ID`
- `--permission-mode MODE`
- `--system-prompt TEXT`, `--system-prompt-file PATH`
- `--append-system-prompt TEXT`, `--append-system-prompt-file PATH`
- `--add-dir DIR`, `--allowed-tools RULE`, `--disallowed-tools RULE`
- `--settings VALUE`, `--mcp-config PATH`, `--fallback-model MODEL`
- `--max-turns N`, `--max-budget-usd AMOUNT`

Short options without a value MAY be bundled; `-nc` equals `-n -c`. Options that take a value SHALL NOT be bundled. When both `-v` and `-q` are given, the last one SHALL win.

#### Scenario: Bundled options
- **WHEN** the user runs `opus -nc go ahead`
- **THEN** dry run and continue are both on and the prompt is `go ahead`

#### Scenario: Verbose then quiet
- **WHEN** the user runs `opus -v -q commit`
- **THEN** quiet output applies

#### Scenario: Line-mode options at run time
- **WHEN** a script runs `zco opus --shell summarize the diff`
- **THEN** Claude Code runs with the prompt `summarize the diff` and no error is printed

### Requirement: Option values
An option that takes a value SHALL accept it as the next argument, or, for long options, as `--option=VALUE`. The value SHALL be taken as given, even when it starts with `-` or is an effort word. An option at the end of the arguments with no value SHALL be a usage error naming the option.

#### Scenario: Value in the next argument
- **WHEN** the user runs `opus --agent reviewer high check this`
- **THEN** the agent is `reviewer`, the effort is `high` and the prompt is `check this`

#### Scenario: Value with equals
- **WHEN** the user runs `opus --system-prompt='Be terse.' summarize`
- **THEN** the system prompt is `Be terse.` and the prompt is `summarize`

#### Scenario: Missing value
- **WHEN** the user runs `opus --agent`
- **THEN** a usage error naming `--agent` is printed and Claude Code is not run

### Requirement: Unknown options
An argument starting with `-` before the prompt that is not a recognised option or bundle SHALL be a usage error. The error names the argument and suggests `--` to start a prompt with a dash.

#### Scenario: Typo in an option
- **WHEN** the user runs `opus -x commit`
- **THEN** a usage error naming `-x` and suggesting `--` is printed and Claude Code is not run

### Requirement: Help
`-h` or `--help` before the prompt SHALL print usage for the invoked command on stdout and exit with status 0 without running Claude Code. Usage covers the grammar, every option, the effort words, the configuration files and the environment variables.

#### Scenario: Help for a model command
- **WHEN** the user runs `sonnet -h`
- **THEN** usage naming `sonnet` is printed on stdout, the exit status is 0 and Claude Code is not run

### Requirement: Prompt or piped input required
A run SHALL need a prompt, a skill (`-s`), input piped or redirected into the command, or a combination of these. With none of them, the command SHALL fail with a usage error. Input counts when stdin is a pipe or a regular file.

#### Scenario: Nothing to send
- **WHEN** the user runs `opus xhigh` in an interactive terminal
- **THEN** a usage error is printed, the exit status is 2 and Claude Code is not run

#### Scenario: Piped input without a prompt
- **WHEN** the user runs `git diff | haiku`
- **THEN** Claude Code runs with the diff as its input and no prompt argument

### Requirement: Usage errors
A usage error SHALL print, on stderr, a message prefixed with the invoked command name, followed by a one-line usage summary. The exit status SHALL be 2. Claude Code SHALL NOT be run and no header SHALL be printed.

#### Scenario: Error names the prefixed command
- **WHEN** `ZCO_PREFIX="c-"` is set and the user runs `c-opus -x commit`
- **THEN** the error message starts with `c-opus:`
