# Spec Delta

## Purpose

Lets users keep defaults in a user file and in per-project files instead of environment variables: permission mode, effort, system prompts, tools, directories and more. Precedence is predictable, the files are never executed, and a project file cannot give a repository new ways to run programs.

## ADDED Requirements

### Requirement: Configuration file locations
The plugin SHALL read up to two configuration files:
- **User file:** the file named by `ZCO_CONFIG` when that variable is set; otherwise `~/.zco.config`.
- **Project file:** the nearest file named `.zco.config` in the current directory or one of its parents. The user file does not count as a project file.

Only one project file SHALL apply. When `ZCO_LOCAL_CONFIG` is false, no project file SHALL be read. A missing file SHALL be ignored silently.

#### Scenario: Nearest project file wins
- **WHEN** both `~/work/a/.zco.config` and `~/work/a/b/.zco.config` exist and the user runs `opus summarize` in `~/work/a/b/c`
- **THEN** only `~/work/a/b/.zco.config` is used as the project file

#### Scenario: Home file is not a project file
- **WHEN** only `~/.zco.config` exists and the user runs `opus summarize` in `~/work/a`
- **THEN** `~/.zco.config` is used as the user file and no project file applies

#### Scenario: Alternative user file
- **WHEN** `ZCO_CONFIG=~/dotfiles/zco.config` is set
- **THEN** that file is read as the user file and `~/.zco.config` is not read

#### Scenario: Project lookup turned off
- **WHEN** `ZCO_LOCAL_CONFIG=0` is set and `./.zco.config` exists
- **THEN** no project file is read

#### Scenario: No configuration files
- **WHEN** neither a user file nor a project file exists
- **THEN** the run uses built-in defaults and prints no warning

### Requirement: File format
A configuration file SHALL be text with one entry per line, parsed as follows:
- An entry has the form `key = value`. Whitespace around the key, the `=` and the value is ignored.
- Blank lines, and lines whose first non-blank character is `#` or `;`, SHALL be ignored.
- A line `[<model>]` starts a section whose entries apply only when that model runs. Entries before the first section apply to every model.
- A value wrapped in matching single or double quotes has those quotes removed. No other quote removal, escape processing or expansion SHALL take place.
- For path-valued keys, a leading `~/` is expanded.

The file SHALL NOT be executed or evaluated.

#### Scenario: Sections apply per model
- **WHEN** the user file contains `effort = medium` followed by a section `[opus]` with `effort = xhigh`
- **THEN** `opus summarize` runs with effort `xhigh` and `sonnet summarize` runs with effort `medium`

#### Scenario: Quoted value keeps spaces
- **WHEN** the user file contains `append_system_prompt = "  Answer tersely.  "`
- **THEN** the appended system prompt is `  Answer tersely.  ` with its spaces kept

#### Scenario: No evaluation
- **WHEN** a configuration file contains `system_prompt = $(touch /tmp/pwned)`
- **THEN** the system prompt is that literal text and `/tmp/pwned` is not created

### Requirement: Configuration keys
The keys listed below SHALL be recognised; the capability named in brackets defines what each one does. A scalar key named `<key>` has the environment variable `ZCO_<KEY>` (the key in upper case). List keys have no environment variable. Boolean values follow the model-commands rule for boolean variables.

| key | value | command-line form | allowed in a project file |
|---|---|---|---|
| `models` | model names separated by whitespace [model-commands] | — | no |
| `prefix` | command-name prefix [model-commands] | — | no |
| `raw_line` | `literal`, `shell` or `off`; boolean words accepted [raw-line-capture] | `--literal`, `--shell` (per line) | no |
| `claude_cmd` | Claude Code command words [claude-invocation] | — | no |
| `extra_args` | list of arguments [claude-options] | — | no |
| `mcp_config` | list of paths [claude-options] | `--mcp-config` | no |
| `permission_mode` | mode [claude-invocation] | `--permission-mode`, `-n` | yes, except `bypassPermissions` |
| `effort` | effort level [claude-invocation] | effort word, `-e` | yes |
| `mcp` | boolean [claude-invocation] | `-m` | yes |
| `session_persistence` | boolean, default true [claude-invocation] | — | yes |
| `max_budget_usd` | decimal [claude-invocation] | `--max-budget-usd` | yes |
| `max_turns` | positive integer [claude-options] | `--max-turns` | yes |
| `agent` | agent name [claude-options] | `-a`, `--agent` | yes |
| `system_prompt`, `system_prompt_file` | text or path [claude-options] | `--system-prompt`, `--system-prompt-file` | yes |
| `append_system_prompt`, `append_system_prompt_file` | text or path [claude-options] | `--append-system-prompt`, `--append-system-prompt-file` | yes |
| `add_dir` | list of paths [claude-options] | `--add-dir` | yes |
| `allowed_tools`, `disallowed_tools` | list of rules [claude-options] | `--allowed-tools`, `--disallowed-tools` | yes |
| `settings` | path or JSON [claude-options] | `--settings` | no |
| `fallback_model` | model name [claude-options] | `--fallback-model` | yes |

#### Scenario: Scalar key through the environment
- **WHEN** `ZCO_AGENT=reviewer` is set and no file sets `agent`
- **THEN** Claude Code receives `--agent reviewer`

### Requirement: Precedence
The effective value of each setting SHALL come from the highest layer that sets it. The layers, from lowest to highest, are:
1. Built-in default.
2. User file, outside any section.
3. User file, section of the running model.
4. Project file, outside any section.
5. Project file, section of the running model.
6. Environment.
7. Command line.

Within one layer, a later line SHALL override an earlier one for scalar keys.

#### Scenario: Project beats user
- **WHEN** the user file sets `effort = medium` in a section `[opus]` and the project file sets `effort = low` outside any section
- **THEN** `opus summarize` runs with effort `low`

#### Scenario: Environment beats files
- **WHEN** the project file sets `permission_mode = acceptEdits` and `ZCO_PERMISSION_MODE=plan` is set
- **THEN** Claude Code receives `--permission-mode plan`

#### Scenario: Command line beats everything
- **WHEN** every layer sets `effort` and the user runs `opus max summarize`
- **THEN** Claude Code receives `--effort max`

### Requirement: List keys
Repeated lines of a list key in the same layer SHALL accumulate in file order. When a layer sets a list key, that list SHALL replace the lists from lower layers. A line `key =` with an empty value SHALL clear the list at that layer. Values given on the command line SHALL be appended to the effective list.

#### Scenario: Repeated list lines
- **WHEN** the project file contains `allowed_tools = Bash(git *)` and `allowed_tools = Edit`
- **THEN** both rules are used, in that order

#### Scenario: Project list replaces user list
- **WHEN** the user file sets `add_dir = ~/notes` and the project file sets `add_dir = ../shared-lib`
- **THEN** only `../shared-lib`, resolved against the project file's directory, is used

#### Scenario: Command line appends
- **WHEN** the project file sets `add_dir = ../shared-lib` and the user runs `opus --add-dir /tmp/data summarize`
- **THEN** both directories are passed, the project one first

### Requirement: Relative paths in files
A relative path in a path-valued key SHALL be resolved against the directory of the file that contains it. Paths given on the command line or in the environment SHALL be resolved against the current directory.

#### Scenario: Prompt file next to the project config
- **WHEN** `~/proj/.zco.config` contains `append_system_prompt_file = prompts/style.md` and the user runs `opus summarize` in `~/proj/src`
- **THEN** the appended system prompt file used is `~/proj/prompts/style.md`

### Requirement: Validation
A configuration file with a malformed line, an unknown key or an invalid value SHALL cause a usage error when the next command runs. The error names the file and line number. The exit status SHALL be 2 and Claude Code SHALL NOT be run. Section names SHALL NOT be validated.

#### Scenario: Unknown key
- **WHEN** line 3 of the user file is `efort = high`
- **THEN** `opus summarize` fails with a message naming the user file, line 3 and `efort`, the exit status is 2 and Claude Code is not run

#### Scenario: Invalid value
- **WHEN** the project file contains `max_turns = many`
- **THEN** the run fails with a message naming the project file, the line and `max_turns`

### Requirement: Keys restricted to the user file
A project file SHALL NOT set these keys: `claude_cmd`, `extra_args`, `mcp_config`, `settings`, `models`, `prefix`, `raw_line`. It SHALL NOT set `permission_mode` to `bypassPermissions`. A project file that does SHALL cause a usage error naming the key and the file, and Claude Code SHALL NOT be run.

#### Scenario: Project file sets the Claude command
- **WHEN** a cloned repository's `.zco.config` contains `claude_cmd = ./run-me.sh` and the user runs `opus summarize` inside it
- **THEN** the run fails with a message saying `claude_cmd` is only allowed in the user file, and `./run-me.sh` is not run

#### Scenario: Project file asks for bypassPermissions
- **WHEN** a project file contains `permission_mode = bypassPermissions`
- **THEN** the run fails with a message naming `permission_mode` and the project file

### Requirement: When files are read
The load-time keys `models`, `prefix` and `raw_line` SHALL be read from the user file once, when the plugin loads. Every other key SHALL be read from both files at every run, so edits take effect at the next run without reloading the plugin.

#### Scenario: Editing a file between runs
- **WHEN** the user runs `opus summarize`, then adds `effort = high` to the project file, then runs `opus summarize` again
- **THEN** the second run receives `--effort high`

### Requirement: Showing the effective configuration
`--show-config` SHALL print, on stdout, every setting that affects a run of the invoked command's model: its effective value and its source. The source is `built-in`, `<file>:<line>`, the environment variable name, or `command line`. The command SHALL then exit with status 0 without running Claude Code. Other options given with it SHALL be reflected in the output.

#### Scenario: Show where the effort comes from
- **WHEN** the user file sets `effort = xhigh` on line 4 in a section `[opus]` and the user runs `opus --show-config`
- **THEN** stdout shows `effort` with value `xhigh` and source `~/.zco.config:4`, and Claude Code is not run

#### Scenario: Command line reflected
- **WHEN** the user runs `opus -n --show-config`
- **THEN** stdout shows `permission_mode` with value `plan` and source `command line`
