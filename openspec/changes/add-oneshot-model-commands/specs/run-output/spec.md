# Spec Delta

## Purpose

Defines what a one-shot run prints and where. The final answer goes alone to stdout, so it can be piped. The header and progress go to stderr, so a misread effort word or a stalled run is visible at once.

## ADDED Requirements

### Requirement: Header line
Before Claude Code starts, one header line SHALL be printed on stderr. It holds the model, the effort, the permission mode and the current directory, separated by ` · `.
- The effort is the level passed to Claude Code, `settings` when none is passed, or `n/a` for haiku models.
- The directory uses `~` for the home directory and named directories.
- Markers are appended, in this order, when they apply:
  - ` · continue` with `-c`, or ` · resume` with `-r`;
  - ` · agent <name>` when an agent is set;
  - ` · /<skill>` with `-s`;
  - ` · mcp` when MCP servers may load (`mcp` true or MCP configuration files given);
  - ` · local config` when a project configuration file applies.

The header SHALL NOT be printed with `-q`, for `-h` or `--show-config`, or on a usage error.

#### Scenario: Explicit effort
- **WHEN** the user runs `opus xhigh commit local changes` in `~/proj`
- **THEN** stderr starts with the line `opus · xhigh · auto · ~/proj`

#### Scenario: Effort left to settings
- **WHEN** the user runs `sonnet fix the typo` in `~/proj` without any effort configured
- **THEN** the header is `sonnet · settings · auto · ~/proj`

#### Scenario: Haiku dry run follow-up
- **WHEN** the user runs `haiku -n -c go ahead` in `~/proj`
- **THEN** the header is `haiku · n/a · plan · ~/proj · continue`

#### Scenario: Agent, skill and project file
- **WHEN** `~/proj/.zco.config` sets `agent = reviewer` and the user runs `sonnet -s review the diff` in `~/proj`
- **THEN** the header is `sonnet · settings · auto · ~/proj · agent reviewer · /review · local config`

### Requirement: Final answer alone on stdout
Stdout SHALL carry only Claude Code's final answer, followed by a newline. The header, progress, notices and plugin errors SHALL go to stderr. Claude Code's own stderr SHALL pass through unchanged. The stdout content SHALL be the same whether or not progress is rendered.

#### Scenario: Answer piped to another command
- **WHEN** the user types `opus --shell write a commit message for the staged changes | pbcopy` in a terminal and presses Enter
- **THEN** only the answer text reaches `pbcopy`, and the header and progress appear on the terminal

#### Scenario: Same answer in both modes
- **WHEN** the same Claude Code output is produced once with progress rendered and once without
- **THEN** the bytes written to stdout are identical

### Requirement: Live progress
Progress SHALL be rendered when stderr is a terminal and `-q` is not given, or when `-v` is given. While Claude Code runs, the plugin SHALL print one line on stderr per tool call, in the form `→ <Tool>  <summary>`. The summary is the most relevant input of the call: the command for shell tools, the path for file tools, the pattern for search tools, the URL or query for web tools, the description for subagents and the name for skills. It is reduced to a single line and, without `-v`, truncated to the terminal width. When progress is not rendered, Claude Code SHALL run with its default text output.

#### Scenario: Shell tool call
- **WHEN** stderr is a terminal and Claude Code runs the shell command `git diff --stat` during the run
- **THEN** stderr shows the line `→ Bash  git diff --stat` while the run continues

#### Scenario: stderr not a terminal
- **WHEN** the user runs `opus summarize 2> log.txt` without `-v`
- **THEN** no progress lines are written and Claude Code is not asked for streaming output

### Requirement: Verbose output
With `-v`, progress SHALL be rendered even when stderr is not a terminal. Progress SHALL also show Claude Code's intermediate text messages, and summaries SHALL NOT be truncated. After the run, a closing line SHALL show duration, number of turns and reported cost.

#### Scenario: Verbose into a log file
- **WHEN** the user runs `opus -v summarize 2> log.txt`
- **THEN** `log.txt` contains the header, one line per tool call, intermediate text messages and a closing summary line

### Requirement: Quiet output
With `-q`, the plugin SHALL print no header, no progress and no notices. Errors SHALL still be printed on stderr and the final answer SHALL still be written to stdout.

#### Scenario: Quiet run in a terminal
- **WHEN** the user runs `haiku -q xhigh summarize` in a terminal
- **THEN** stderr receives neither the header, progress lines nor the haiku effort notice, and the answer appears on stdout

### Requirement: Fallback without jq
When `jq` is not available, the plugin SHALL run Claude Code with its default text output and render no progress. The final answer SHALL still be delivered on stdout. With `-v`, one notice SHALL say that live progress needs `jq`.

#### Scenario: jq missing in a terminal
- **WHEN** `jq` is not on the `PATH` and the user runs `opus summarize` in a terminal
- **THEN** Claude Code is not asked for streaming output and the answer appears on stdout

#### Scenario: jq missing with verbose
- **WHEN** `jq` is not on the `PATH` and the user runs `opus -v summarize`
- **THEN** one notice mentioning `jq` is printed on stderr

### Requirement: Errors reported during progress
While progress is rendered, an error result reported by Claude Code (such as the budget being exceeded) SHALL be shown as one line on stderr naming the error kind. Lines in Claude Code's output that are not valid JSON SHALL be forwarded to stderr, not dropped, and SHALL NOT stop the rendering.

#### Scenario: Budget exceeded
- **WHEN** Claude Code reports an error result of kind `error_max_budget_usd`
- **THEN** stderr shows one line naming `error_max_budget_usd`, and the command returns Claude Code's exit status

#### Scenario: Non-JSON line in the stream
- **WHEN** Claude Code writes a plain-text warning line among its streaming output
- **THEN** that line appears on stderr and later progress lines and the final answer are still shown

### Requirement: Terminal styling
Header and progress lines SHALL use dim styling only when stderr is a terminal and `NO_COLOR` is unset. Otherwise no escape sequences SHALL be written.

#### Scenario: NO_COLOR set
- **WHEN** `NO_COLOR=1` is set and the user runs `opus summarize` in a terminal
- **THEN** the header and progress lines contain no escape sequences
