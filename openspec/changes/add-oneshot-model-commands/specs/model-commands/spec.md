# Spec Delta

## Purpose

Loads the plugin into zsh and exposes one command per Claude model (e.g. `opus`, `sonnet`), plus a `zco` entry point, so a one-shot Claude Code prompt can be fired from the current directory.

## ADDED Requirements

### Requirement: Plugin entry file
The plugin SHALL be loaded by sourcing `zsh-claude-oneshot.plugin.zsh` at the repository root. Loading SHALL work from any current directory, through an absolute path, a relative path or a symbolic link. The plugin SHALL find its own files relative to the real location of the entry file.

#### Scenario: Sourced from another directory
- **WHEN** a user in `/tmp` runs `source ~/src/zsh-claude-oneshot/zsh-claude-oneshot.plugin.zsh`
- **THEN** the per-model commands and `zco` are defined and usable

#### Scenario: Sourced through a symlink
- **WHEN** the entry file is sourced through a symbolic link located in another directory
- **THEN** the plugin loads all of its functions from the directory of the real file

### Requirement: Quiet and repeatable loading
Loading SHALL NOT write to stdout. Sourcing the plugin again in the same shell SHALL leave exactly one definition of each command and exactly one line-rewrite hook. It SHALL NOT report the plugin's own earlier definitions as name collisions.

#### Scenario: Sourced twice
- **WHEN** the plugin is sourced twice in the same shell with default settings
- **THEN** nothing is written to stdout or stderr, and each command and hook is registered once

### Requirement: Minimum zsh version
The plugin SHALL require zsh 5.3 or newer. On an older zsh, loading SHALL print one warning line on stderr and define nothing.

#### Scenario: Old zsh
- **WHEN** the plugin is sourced in zsh 5.2
- **THEN** one warning naming the minimum version is printed on stderr and no command is defined

### Requirement: One command per model
The plugin SHALL define one command per entry of the `models` setting. The setting comes from `ZCO_MODELS` (an array, or a string split on whitespace), or else from `models` in the user configuration file (split on whitespace). Its default is `fable opus sonnet haiku`. Running `<command> <args…>` SHALL behave exactly as `zco <model> <args…>` for that command's model.

#### Scenario: Default model set
- **WHEN** the plugin is loaded without `ZCO_MODELS` set
- **THEN** the commands `fable`, `opus`, `sonnet` and `haiku` are defined

#### Scenario: Custom model list
- **WHEN** `ZCO_MODELS=(opus haiku)` is set before loading
- **THEN** only `opus` and `haiku` are defined

#### Scenario: Model list as a string
- **WHEN** `ZCO_MODELS="opus  sonnet"` is set before loading
- **THEN** only `opus` and `sonnet` are defined

#### Scenario: Model list from the user file
- **WHEN** `ZCO_MODELS` is unset and the user file contains `models = opus haiku`
- **THEN** only `opus` and `haiku` are defined

### Requirement: Command name prefix
When the `prefix` setting is set (`ZCO_PREFIX`, or `prefix` in the user file), each command name SHALL be the prefix followed by the model name. The model passed to Claude Code SHALL stay the unprefixed model name.

#### Scenario: Prefixed commands
- **WHEN** `ZCO_PREFIX="c-"` is set before loading and the user runs `c-opus commit local changes`
- **THEN** `c-opus` runs Claude Code with model `opus`, and no command named `opus` is defined by the plugin

### Requirement: Opting out of per-model commands
When `ZCO_MODELS` is set but empty, or the user file contains `models =` with an empty value, the plugin SHALL define no per-model commands. `zco` SHALL remain available.

#### Scenario: Empty model list
- **WHEN** `ZCO_MODELS=()` is set before loading
- **THEN** no per-model command is defined and `zco opus commit local changes` still works

### Requirement: Name collisions
The plugin SHALL NOT replace an existing name. If a command name (or `zco`) already exists as an alias, function, builtin, reserved word or external command, and was not defined by an earlier load of this plugin, that name SHALL be skipped. The plugin SHALL print one warning line on stderr naming the command and suggesting `ZCO_PREFIX`.

#### Scenario: Name taken by an existing function
- **WHEN** the user's shell already has a function named `haiku` and the plugin is loaded with default settings
- **THEN** the function `haiku` is unchanged, the other commands are defined, and one warning mentioning `haiku` and `ZCO_PREFIX` is printed on stderr

### Requirement: Invalid model entries
An entry of `ZCO_MODELS` that is not a valid command name SHALL be skipped with one warning line on stderr. Valid names start with a letter or digit and contain only letters, digits, `.`, `_` and `-`.

#### Scenario: Entry with brackets
- **WHEN** `ZCO_MODELS=(opus 'sonnet[1m]')` is set before loading
- **THEN** `opus` is defined, no command is defined for `sonnet[1m]`, and one warning names the skipped entry

### Requirement: zco entry point
The plugin SHALL provide `zco <model> [effort] [flags] [--] prompt…`. It accepts any model name, including ones that are not valid command names. It follows normal zsh quoting, globbing and redirection rules. `zco` without a model, or with a model starting with `-`, SHALL be a usage error.

#### Scenario: Model without a command
- **WHEN** the user runs `zco 'opus[1m]' summarize this repo`
- **THEN** Claude Code runs with model `opus[1m]` and prompt `summarize this repo`

#### Scenario: Redirecting output
- **WHEN** the user runs `zco opus 'write release notes' > notes.md`
- **THEN** the final answer is written to `notes.md`

#### Scenario: Missing model
- **WHEN** the user runs `zco` with no arguments
- **THEN** a usage error is printed on stderr, the exit status is 2 and Claude Code is not run

### Requirement: Glob-safe arguments
Per-model commands SHALL receive their arguments without filename generation. `?`, `*`, `[` and `]` in an unquoted prompt SHALL reach Claude Code literally, even with raw-line capture turned off.

#### Scenario: Glob characters with raw-line capture off
- **WHEN** `ZCO_RAW_LINE=0` and the user runs `opus which *.md files mention [install]?`
- **THEN** Claude Code receives the prompt `which *.md files mention [install]?` and no "no matches found" error occurs

### Requirement: Independence from user shell options
The plugin's behaviour SHALL NOT depend on the user's shell options. It SHALL NOT change them. This covers, among others, `KSH_ARRAYS`, `SH_WORD_SPLIT`, `NO_UNSET`, `ERR_EXIT`, `EXTENDED_GLOB`, `NULL_GLOB` and `NO_ALIASES` inside functions.

#### Scenario: Unusual options set
- **WHEN** the user has `setopt KSH_ARRAYS SH_WORD_SPLIT NO_UNSET EXTENDED_GLOB` and runs `opus xhigh commit local changes`
- **THEN** Claude Code receives the same arguments as with default options, and the user's options are unchanged afterwards

### Requirement: Configuration sources
Settings SHALL come from the configuration files, the environment and the command line, with the precedence and keys defined in the configuration capability. When they are read:
- Once, at load time: `models`, `prefix`.
- At load time and for every accepted line: `raw_line`.
- At every run: all other settings.

Only these environment variables SHALL be recognised:
- `ZCO_<KEY>` for each scalar configuration key;
- `ZCO_EFFORT_<MODEL>`;
- `ZCO_CONFIG` and `ZCO_LOCAL_CONFIG`.

Boolean values, in variables and files, SHALL treat `1`, `true`, `yes` and `on` as true and `0`, `false`, `no` and `off` as false, ignoring case. Any other value SHALL be a usage error naming its source. No variable SHALL use the `CLAUDE_` prefix.

#### Scenario: Changing a run-time setting in a live shell
- **WHEN** the user runs `export ZCO_PERMISSION_MODE=acceptEdits` after loading and then runs `opus fix the typo`
- **THEN** Claude Code runs with permission mode `acceptEdits` without reloading the plugin

#### Scenario: Boolean spelled differently
- **WHEN** `ZCO_MCP=Yes` is set
- **THEN** it is treated as true

#### Scenario: Invalid boolean
- **WHEN** `ZCO_MCP=maybe` is set and the user runs `opus summarize`
- **THEN** a usage error naming `ZCO_MCP` is printed and Claude Code is not run
