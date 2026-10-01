# Proposal

<!-- Revision 1.1.0 (2026-09-30): adds curated Claude Code options, .zco.config user/project configuration and --show-config. Previous revision 1.0.0 kept as a snapshot outside the repository. -->
<!-- Revision 1.2.0 (2026-10-01): raw-line line modes (--shell / --literal, raw_line = literal | shell | off); all open decisions resolved. -->

## Why

Running a quick task with Claude Code from the shell ("prepare a commit", "edit README.md: add an install section", "reorganise this folder by year") today means opening an interactive session, or typing a long `claude -p --model … --permission-mode … "…"` line with careful quoting. zsh users want to fire a one-shot prompt from the current directory as easily as any other command. The model is the command and the prompt is typed unquoted, so it can hold apostrophes, `>`, `|`, `?` or `*`.

Defaults that repeat across runs belong in a file rather than on every command line: a house style appended to the system prompt, an agent for one repository, tool rules or extra directories. Examples of such defaults are the preferred effort per model and the permission mode.

## What Changes

- New zsh plugin `zsh-claude-oneshot.plugin.zsh`, loadable by oh-my-zsh (custom plugin), antidote, zinit, zap or plain `source`.
- One command per model (default `fable opus sonnet haiku`), with an optional name prefix (e.g. `c-opus`) and an opt-out. A public `zco <model> …` entry point covers scripts, redirections and users who opt out of the per-model commands.
- Grammar `<model> [effort] [flags] [--] prompt…`:
  - An optional bare effort word (`low|medium|high|xhigh|max`) and `--` to end parsing. `ultracode` is refused.
  - Flags without a value: `-n` (dry run / plan), `-c` (continue), `-m` (MCP), `-v`/`-q`, `-h`, `--show-config`, `--shell`/`--literal` (line mode).
  - Options with a value, starting with `-e LEVEL`; the rest are listed in the next bullet.
- Curated Claude Code options, as command-line options and configuration keys:
  - `-a/--agent`, and `-s/--skill`, which is sent as a `/skill` prompt because Claude Code has no skill flag.
  - `--system-prompt[-file]` and `--append-system-prompt[-file]`.
  - `--add-dir`, `--allowed-tools`, `--disallowed-tools`, `--settings`, `--mcp-config`.
  - `--fallback-model`, `--max-turns`, `--max-budget-usd`, `--permission-mode`, `-r/--resume`.
  - An `extra_args` escape hatch (user file only) for any other flag, filtered against the flags the plugin never passes or already manages.
- Configuration files: a user file (`~/.zco.config`, or `$ZCO_CONFIG`) and the nearest project `.zco.config`.
  - INI-style `key = value` with per-model `[model]` sections. The files are parsed, never executed.
  - Clear precedence: built-in < user < project < environment < command line.
  - `file:line` errors, and `--show-config` to see each effective value and where it came from.
  - A project file cannot set the keys that would let a repository run programs of its choosing (`claude_cmd`, `extra_args`, `mcp_config`, `settings`, `bypassPermissions`).
- Raw-line capture: a ZLE hook quotes the prompt part of a line that starts with a model command before zsh parses it, so `' > | ; & # ! $ * ?` stay part of the prompt. It has three line modes:
  - `literal`, the default: the whole rest of the line is the prompt.
  - `shell`: the prompt ends at the first spaced shell operator and zsh handles the rest, so `opus --shell write a commit message | pbcopy` pipes the answer.
  - `off`.

  `--shell` and `--literal` choose the mode for one line; `raw_line` sets the default.
- Headless invocation of Claude Code (`-p --model <m> --permission-mode <mode>`) through a configurable command, which may be a shell function or a wrapper such as `env CLAUDE_CONFIG_DIR=… claude`. Behaviour:
  - Permission mode defaults to `auto`; `-n` switches to `plan`.
  - `--effort` is passed only when asked for; haiku drops it and prints a notice.
  - MCP servers are skipped by default for a fast start.
  - An optional budget cap, and an option to skip saving the session.
  - Piped input passes through; otherwise stdin comes from `/dev/null`, which avoids a 3 s wait.
  - The exit status is Claude Code's.
- Output: a one-line header on stderr (model · effort · permission mode · cwd, plus markers such as `agent`, `/skill` and `local config`), the final answer alone on stdout, and live tool-call progress on stderr when stderr is a terminal.
- Tab completion for flags, effort words and option values.
- README covering:
  - install and usage;
  - the `.zco.config` reference;
  - permission modes and the `-n` then `-c` workflow;
  - reusable prompts through Claude Code slash commands and skills;
  - a security note on workspace trust and project files;
  - related projects.
- Tests and CI:
  - a test suite with a recording test double of the Claude Code CLI, so no API calls;
  - direct unit tests of the rewrite, the parser and the config merge;
  - GitHub Actions CI on macOS and Ubuntu;
  - an optional manual smoke test against the real CLI.

Out of scope: shipping prompt recipes, named presets or profiles, a Homebrew formula (a later, separate change) and reimplementing Claude Code's model remapping.

## Capabilities

### New Capabilities
- `model-commands`: plugin loading and the per-model commands. Covers the model list, name prefix, opt-out, name-collision handling, the `zco` entry point, glob safety, isolation from user shell options, and which configuration sources are read when.
- `prompt-grammar`: how a command line is split into effort, options and their values, and prompt. Covers effort words, flags and bundling, `--`, usage errors, help, and when a prompt, skill or piped input is required.
- `configuration`: user and project `.zco.config` files. Covers file locations, format, keys, precedence, list merging, relative paths, validation, keys restricted to the user file, when files are read, and `--show-config`.
- `claude-options`: the curated Claude Code options (agent, skill, system prompts, directories, tool rules, settings, MCP configuration, fallback model, turn limit, permission mode, resume) and the filtered `extra_args`.
- `claude-invocation`: the exact Claude Code invocation. Covers command resolution (wrappers and functions), the argument order, permission mode, effort resolution and the haiku rule, MCP, session persistence, the budget cap, stdin handling, flags that are never passed, and the exit status.
- `run-output`: the stderr header and markers, the stdout-only final answer, live progress, verbose and quiet levels, and fallback when progress cannot be rendered.
- `raw-line-capture`: rewriting of interactive lines that start with a model command. Covers which lines are rewritten, the line modes (literal, shell, off) and their per-line flags, idempotence, continuation lines and coexistence with common ZLE plugins.
- `shell-completion`: tab completion of options, effort words, effort levels and option values for the per-model commands and `zco`.

### Modified Capabilities
None. This is a new project with no existing specs.

## Impact

- New files:
  - the plugin entry file, and autoloaded functions under `functions/`;
  - `README.md` and `LICENSE`;
  - `tests/`: runner, test double, fixtures, and unit, integration and smoke tests;
  - `.github/workflows/ci.yml`.
- Runtime dependencies: zsh ≥ 5.3 and Claude Code. `jq` is optional and only needed for live progress.
- Interactive shells: defines aliases (e.g. `opus`), plus a `zle-line-finish` hook and a `preexec` hook whenever at least one per-model command exists. The hook does nothing for other lines, and with `raw_line = off` it does nothing unless the line has `--literal` or `--shell`.
- Reads `~/.zco.config` (or `$ZCO_CONFIG`) and the nearest `.zco.config` above the current directory on every run.
- Security posture: runs `claude -p` in the current directory, which skips Claude Code's workspace-trust dialog. A project `.zco.config` is read automatically, but it can only set what the repository could already set through its own `.claude/` files. The README documents both.

## Decisions

No open decisions remain. Resolved on 2026-10-01:
- **License:** MIT.
- **Progress parsing:** jq, falling back to plain text output (no live progress) when jq is missing. Pure zsh would need a full JSON string decoder and slow pattern matching on very large lines.
- **Raw-line capture:**
  - The default is `literal`, because with capture off an apostrophe (`don't`) leaves zsh at a `quote>` prompt, and backticks run commands.
  - Per-line `--shell` and `--literal` flags, long options only. `--shell` keeps the prompt literal but lets zsh handle the rest of the line after the first spaced operator, so pipes and redirections still work without hand-quoting.
  - `raw_line = literal | shell | off` sets the default.

Resolved on 2026-09-30:
- **Names:** product `zsh-claude-oneshot`, env prefix `ZCO_`, entry point `zco`, config file `.zco.config`, internal functions `_zco_*`. Taken from your 2026-09-30 revision request, which uses `zco` and `.zco.config`.
- **Config format:** INI-style, parsed without evaluation.
- **Project-file trust:** read automatically; restricted keys are refused. This was chosen over direnv-style explicit trust.
- **Flag scope:** curated first-class options plus filtered `extra_args`.

Smaller assumptions, shown in the artifacts, that you may want to override:

- **Repository contents:** commit `openspec/`, whose specs double as behaviour docs, and keep `.claude/` out of the public repo (`.gitignore`).
- **zsh version:** minimum 5.3, the release that introduced `add-zle-hook-widget`. CI covers 5.9 on macOS and Ubuntu, plus a 5.3.1 container job.
- **Models without a command:** model names that aren't valid command names (e.g. `opus[1m]`) get no command. They can still be used through `zco 'opus[1m]' …`.
- **Short forms:** `-a`, `-s` and `-r`; all other new options are long-only.
- **Project files:** only the nearest project file applies; no merging up the directory tree.
- **Variables and files:** `ZCO_NO_SESSION_PERSISTENCE` from revision 1.0.0 becomes `ZCO_SESSION_PERSISTENCE` (default true), to match the `session_persistence` key.
- **Config errors:** an unknown key in a config file is an error, not a warning, so a typo cannot silently change behaviour.
