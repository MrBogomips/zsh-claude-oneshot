# Spec Delta

## Purpose

Provides zsh tab completion for the per-model commands and `zco`, so options, effort words, effort levels and option values can be discovered without reading the help.

## ADDED Requirements

### Requirement: Option completion
Completing an argument that starts with `-` before the prompt SHALL offer the plugin's options, short and long, each with a short description.

#### Scenario: Complete options
- **WHEN** the user types `opus -` and presses Tab
- **THEN** `-n`, `-c`, `-m`, `-v`, `-q`, `-e`, `-a`, `-s`, `-r` and `-h` are offered with descriptions

#### Scenario: Complete long options
- **WHEN** the user types `opus --app` and presses Tab
- **THEN** `--append-system-prompt` and `--append-system-prompt-file` are offered

#### Scenario: Complete line-mode options
- **WHEN** the user types `opus --sh` and presses Tab
- **THEN** `--shell` and `--show-config` are offered

### Requirement: Option value completion
Completing the value of a path-valued option SHALL offer file names. Those options are `--system-prompt-file`, `--append-system-prompt-file`, `--settings` and `--mcp-config`. `--add-dir` SHALL offer directory names only. `--permission-mode` SHALL offer `acceptEdits`, `auto`, `bypassPermissions`, `manual`, `dontAsk` and `plan`. Other values SHALL be offered no completions.

#### Scenario: Directory completion for --add-dir
- **WHEN** the current directory holds a directory `lib` and a file `lib.md`, and the user types `opus --add-dir li` and presses Tab
- **THEN** `lib/` is offered and `lib.md` is not

#### Scenario: Permission modes
- **WHEN** the user types `opus --permission-mode a` and presses Tab
- **THEN** `acceptEdits` and `auto` are offered

### Requirement: Effort word completion
While no effort is set and the prompt has not started, completing a word SHALL offer the five effort words `low`, `medium`, `high`, `xhigh` and `max`. It SHALL NOT offer `ultracode`.

#### Scenario: Complete effort word
- **WHEN** the user types `opus x` and presses Tab
- **THEN** `xhigh` is completed

### Requirement: Effort level completion
Completing the argument of `-e` or `--effort` SHALL offer only the five effort levels.

#### Scenario: Complete level after -e
- **WHEN** the user types `sonnet -e ` and presses Tab
- **THEN** exactly `low`, `medium`, `high`, `xhigh` and `max` are offered

### Requirement: File completion inside the prompt
After the prompt has started, completion SHALL offer file names, so prompts can refer to files.

#### Scenario: Complete a file name in the prompt
- **WHEN** the current directory holds `README.md` and the user types `sonnet edit REA` and presses Tab
- **THEN** `README.md` is completed

### Requirement: Model completion for zco
Completing the first argument of `zco` SHALL offer the configured model names. Later arguments SHALL complete as for a per-model command.

#### Scenario: Complete a model for zco
- **WHEN** the default models are configured and the user types `zco so` and presses Tab
- **THEN** `sonnet` is completed

### Requirement: Registration regardless of load order
Completion SHALL be registered whether zsh's completion system is initialised before or after the plugin loads. It SHALL work with the `COMPLETE_ALIASES` option set or unset.

#### Scenario: Completion initialised after the plugin
- **WHEN** the plugin is sourced before `compinit` runs and the user then types `opus -` and presses Tab
- **THEN** the plugin's options are offered

#### Scenario: COMPLETE_ALIASES set
- **WHEN** `setopt COMPLETE_ALIASES` is in effect and the user types `opus -e ` and presses Tab
- **THEN** the five effort levels are offered
