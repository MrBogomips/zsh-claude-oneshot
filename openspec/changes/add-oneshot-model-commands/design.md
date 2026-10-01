# Design

<!-- Revision 1.1.0 (2026-09-30): adds Decisions 4 (configuration files) and 5 (curated Claude Code options); later decisions renumbered. -->
<!-- Revision 1.2.0 (2026-10-01): Decision 11 gains line modes (literal / shell / off) and the --shell / --literal flags; open decisions resolved (MIT, jq). -->

## Context

This is a greenfield repository with only OpenSpec scaffolding and no code yet. See `proposal.md` (Why) for motivation and the specs for the behaviour contract. The facts below were checked on 2026-09-30 and constrain the approach.

**Claude Code 2.1.285 flags** (`claude --help`):
- These exist: `-p`, `--model`, `--effort {low,medium,high,xhigh,max}`, `--permission-mode {acceptEdits,auto,bypassPermissions,manual,dontAsk,plan}`, `--strict-mcp-config`, `-c/--continue`, `-r/--resume`, `--no-session-persistence`, `--max-budget-usd` (print mode only), `--output-format stream-json`, `--agent`, `--system-prompt`, `--append-system-prompt`, `--add-dir`, `--allowed-tools`, `--disallowed-tools`, `--settings`, `--mcp-config` and `--fallback-model`.
- `-p` with `stream-json` needs `--verbose`.
- `--add-dir`, `--allowed-tools`, `--disallowed-tools` and `--mcp-config` are variadic (`<values...>`), so they can swallow the arguments that follow them.
- `--permission-prompts none|host` (default `host`) also exists; we do not use it.
- `-p` skips the workspace-trust dialog. The help text says so explicitly.

**Probes without an API call.** `claude -p <flags> </dev/null` fails at parse time, before any API call. Unknown options give `unknown option`; known ones go on to "Input must be provided…" or to their own validation. Results:
- `--system-prompt-file`, `--append-system-prompt-file` and `--max-turns` are accepted even though `--help` does not list them.
- `--skill` is unknown.
- `--agent x` fails with "agent not found" before any API call.
- `--version` short-circuits all validation, so it is not a usable probe.

**zsh 5.9 behaviour, verified in a `zpty` probe.** A widget registered with `add-zle-hook-widget line-finish` that changes `BUFFER` changes the line zsh parses and executes. This holds with an unbalanced `'`, and the history entry is the rewritten line. `!`, `!!`, `!$`, `#`, globs, `~`, `$VAR` and backticks all stay literal once single-quoted by `${(qq)…}`.

**`add-zle-hook-widget` source (zsh 5.9).**
- A `zle-line-finish` widget that already exists (oh-my-zsh defines one before plugins load) is kept as hook `0`.
- Adding the same hook twice is a no-op.
- User hooks are called without `-w`, so `$WIDGET` stays `zle-line-finish`. Wrappers such as zsh-syntax-highlighting's therefore still reach the dispatcher's hook list.

**Performance.** A trivial haiku prompt takes about 9.3 s by default and about 2.8 s with `--strict-mcp-config` and `</dev/null`.

**Tooling on the target machines.** zsh 5.9 on macOS and on Ubuntu 24.04 runners, and jq 1.7 preinstalled on GitHub runners. zsh has no reliable line-coverage tool.

Names follow the resolved naming decision: `zco`, `ZCO_`, `.zco.config` and `_zco_*`.

## Goals / Non-Goals

**Goals:**
- Only pure functions for everything that decides behaviour: token classifier, parser, config parser and merge, effort resolution, argv builder and line rewrite. Tests can then assert results without ZLE, a TTY or the network.
- Configuration files are data, never code.
- No new shell dependencies beyond zsh ≥ 5.3; jq is optional and only for live progress.
- Adding nothing to shell start-up beyond reading the user file once, defining aliases and functions and registering hooks. No subprocesses at load time.
- Robustness against arbitrary user shell options, and against other ZLE plugins loading in any order.

**Non-Goals:**
- Recognising model commands behind leading assignments (`FOO=1 opus …`), `command`/`builtin`/`\` prefixes, or inside pipelines and lists in the raw-line rewrite.
- Named presets or profiles in `.zco.config` (possible follow-up).
- Merging several project files up the directory tree; only the nearest one applies.
- Completing agent names, skill names or slash commands (possible follow-up).
- Supporting zsh < 5.3 or shells other than zsh.
- Line-level code coverage. Decision 14 describes what stands in for it.

## Decisions

### 1. Layout: thin entry file plus autoloaded functions
```
zsh-claude-oneshot.plugin.zsh   # locate self, version check, read load-time keys, fpath+autoload,
                                # define commands, hooks, completion
functions/
  zco                 # public entry: zco <model> …  → _zco_main zco <model> …
  _zco_main           # orchestration: parse → config → resolve → validate → header → run
  _zco_classify       # token classifier shared by parser, rewrite and completion
  _zco_parse          # pure grammar parser (options + values, effort, prompt)
  _zco_keys           # the key schema: type, CLI option, env name, user-only flag
  _zco_config_find    # user file + nearest project file
  _zco_config_read    # pure INI parser: file → layer entries with file:line
  _zco_config_get     # effective value + source of one key across layers
  _zco_config_show    # --show-config output
  _zco_effort         # effort resolution + haiku rule
  _zco_argv           # pure argv builder (fixed order, curated options, extra_args filter)
  _zco_cmd            # resolve claude_cmd / ZCO_CLAUDE_CMD into a word array
  _zco_render         # stream-json → tagged lines (jq); _zco_route dispatches them
  _zco_rewrite        # pure raw-line rewrite: line in, REPLY out
  _zco_line_finish    # ZLE hook: guards, then BUFFER=$(_zco_rewrite)
  _zco_define         # command generation, validation, collision checks
  _zco_complete       # completion function
  _zco_usage, _zco_err, _zco_bool
```
The entry file resolves its own directory with the Zsh Plugin Standard `$0` idiom (`${ZERO:-…}`, then `:A` to follow symlinks). It adds `functions/` to `fpath` and runs `autoload -Uz` on the functions. Every function starts with `emulate -L zsh` (plus `setopt extended_glob warn_create_global` where needed), so user options never leak in and ours never leak out.
- *Alternative:* one large `.plugin.zsh`. Rejected: hard to unit test, and it breaks the small-files rule.
- *Alternative:* `lib/*.zsh` sourced at load. Rejected: it parses all code at start-up for no benefit.

### 2. Per-model commands are aliases to `noglob _zco_main <name> <model>`
Only an alias can put the `noglob` precommand modifier in front of the arguments. A function receives its arguments after globbing has already happened. For example, `c-opus` becomes `alias c-opus='noglob _zco_main c-opus opus'`, and the first argument carries the invoked name for error messages. `zco` is a plain function (normal globbing and quoting) that calls `_zco_main zco "$@"`.

**Collisions** are checked with `whence -w <name>`. An alias whose value is exactly our `noglob _zco_main <name> <model>` counts as ours, which makes re-sourcing idempotent. Anything else is skipped with one warning on stderr. Warnings appear only on misconfiguration, which is also the only case where Powerlevel10k's instant prompt would complain about console output.

**`models` and `prefix`** come from `ZCO_MODELS`/`ZCO_PREFIX`, or else from the user file. `_zco_config_read` parses the user file at load for just these keys. Entries must match `[A-Za-z0-9][A-Za-z0-9._-]#`.

### 3. Hand-written parser around a shared token classifier
`zparseopts` stops at the first non-option word and cannot interleave the bare effort word with options. So the parser is a loop over `_zco_classify <token> <effort_already_set>`, which returns one of:

| class | tokens |
|---|---|
| `end` | `--` |
| `effort` | `low medium high xhigh max`, only while no effort is set |
| `value-opt` | `-e -a -s -r` and the long options that take a value (consume next token) |
| `value-eq` | `--<long-value-option>=*` |
| `flag` | `-n -c -m -v -q -h`, `--show-config`, `--shell`, `--literal`, long forms, bundles `-[ncmvqh]##` |
| `ultracode` | `ultracode` (usage error unless after `--`) |
| `unknown` | any other `-?*` |
| `prompt` | everything else, including a bare `-` |

The value-option table comes from `_zco_keys`, the single list of option names, config keys and env names. The parser, rewrite, completion, `--show-config` and help therefore cannot disagree about which options exist.

The parser writes into locals declared by the caller. zsh's dynamic scoping makes this the idiomatic "return a struct" pattern. It has no I/O; errors come back as a status plus a message in `REPLY`. List options (`--add-dir`, `--allowed-tools`, `--disallowed-tools`, `--mcp-config`) accumulate into arrays.

**Rejecting `ultracode`.** `ultracode` as the first prompt word is refused as well as `-e ultracode`. Claude Code reads that keyword in a prompt as consent to start multi-agent workflows. `--` keeps a deliberate escape.

### 4. Configuration files: INI data merged over seven layers
**Discovery** (`_zco_config_find`, every run):
- User file: `$ZCO_CONFIG`, else `~/.zco.config`.
- Project file: walk up from `$PWD` to `/`, taking the first `.zco.config` whose `:A` path differs from the user file's. This is skipped when `ZCO_LOCAL_CONFIG` is false.

**Parsing** (`_zco_config_read`, pure) is a `while IFS= read -r line || [[ -n $line ]]` loop with a line counter:
- It strips comments and blank lines, tracks `[section]`, and splits entries on the first `=`.
- It trims key and value, and removes one pair of matching outer quotes.
- It checks each key against `_zco_keys`: known key, value of the right type, not user-only when reading the project file.
- It resolves relative paths against `${file:A:h}` and expands a leading `~/`.
- Nothing is ever evaluated.

Results land in an associative array keyed `<layer>|<section>|<key>`, with a parallel `file:line` source map. Lists are NUL-joined and split back with `${(0)…}`, so a rule like `Bash(git *)` keeps its spaces. A malformed line or a bad value fails the run as a usage error naming `file:line`; failing fast means a typo can never silently change a run.

**Merge** (`_zco_config_get <key>`) walks the layers from highest to lowest:
1. Command line.
2. Environment: `ZCO_<KEY>`, with `ZCO_EFFORT_<MODEL>` above `ZCO_EFFORT`.
3. Project file, model section.
4. Project file, outside sections.
5. User file, model section.
6. User file, outside sections.
7. Built-in default.

It returns the value in `REPLY` and the source in `reply_src`. For list keys it takes the highest file or env layer that sets the list, then appends the command-line values. Two small files are parsed per run, which costs well under a few milliseconds, so there is no cache.

**Keys only the user file may set:** `claude_cmd`, `extra_args`, `mcp_config`, `settings`, `models`, `prefix`, `raw_line`, and `permission_mode = bypassPermissions`. Everything else a project file may set, the repository can already set through its own `.claude/` directory, which Claude Code loads without asking in `-p` mode:
- `append_system_prompt` and `system_prompt` correspond to CLAUDE.md and output styles.
- `allowed_tools`, `disallowed_tools`, `add_dir` and `permission_mode` correspond to `permissions.allow/deny/additionalDirectories/defaultMode`.
- `agent` corresponds to `.claude/agents`.

The restricted keys would add new ways to run programs:
- `claude_cmd` runs an arbitrary program before Claude Code starts.
- `extra_args` could pass `--plugin-url`, `--plugin-dir` and similar.
- `mcp_config` starts servers without the approval that project `.mcp.json` servers need.
- `settings` would lift repository-provided settings into command-line scope.
- `bypassPermissions` escalates the permission mode.

**`--show-config`** prints INI-style lines to stdout, for example `effort = xhigh    # ~/.zco.config:4`, one per key in schema order. They are preceded by comment lines naming the user and project files found. The output is copy-pasteable into a config file and doubles as the main tool for precedence tests.

- *Alternative:* a sourced zsh file. Rejected: a cloned repository's file would run code on every command.
- *Alternative:* JSON. Rejected: it would make jq a hard dependency.
- *Alternative:* TOML. Rejected: its string and table rules are too much to parse correctly in zsh.
- *Alternative:* direnv-style explicit trust. Rejected: it adds friction for no real gain, because Claude Code already loads the repository's `.claude/` unasked.

### 5. Curated Claude Code options
Each curated option maps 1:1 to the Claude Code flag of the same name. The exceptions:
- **Skill.** Claude Code has no skill flag, so `-s NAME` becomes a prompt prefix: `"/NAME"` plus `" <prompt>"` when there is a prompt. Skills and slash commands work in `-p` mode. The name is checked against `[A-Za-z0-9][A-Za-z0-9:._-]*` (plugin skills use `plugin:skill`). A skill is not a config key, because a default skill applied to every run makes no sense.
- **System prompts.** Text and file form of the same prompt form one setting group: the highest layer holding either form wins, and giving both in one layer is an error. Prompt files are checked with `[[ -r ]]` before running, so the error names the path the user wrote, not Claude Code's resolved one.
- **Lists** become repeated `--flag value` pairs. Together with the `--` before the prompt (Decision 6), this keeps the variadic flags from swallowing the prompt.
- **`--mcp-config` with `--strict-mcp-config`** means "only these servers". `-m` or `mcp = true` drops the strict flag, which gives "the configured servers plus these".
- **`-r ID`** and `-c` are mutually exclusive. The ID is required, because the interactive picker cannot work in `-p` mode.
- **`extra_args`** (user file only) is appended as-is after the curated options. Each element is rejected, as a plain flag or in `--flag=…` form, when it is any of the following:
  - a never-pass flag;
  - a flag zco manages (`-p/--print`, `--model`, `--permission-mode`, `--effort`, `--output-format`, `--input-format`, `--verbose`, `-c/--continue`, `-r/--resume`, `--strict-mcp-config`, `--no-session-persistence`, `--max-budget-usd`, or any curated option);
  - a bundle of short options (long forms are required, so a managed letter cannot hide inside a bundle).

### 6. Argument builder with a fixed order
`_zco_argv` is a pure function from the parsed options and the effective settings to `reply=( … )`. It uses the 19-position order in the claude-invocation spec, so tests can compare the whole argv exactly.

The prompt is passed after `--` as a single argument. A prompt that starts with `-` is then never read as a Claude Code flag, and no variadic flag can consume it. **Task 1.3 verifies this** with one real haiku call before the argv tests are frozen. If `--` turned out to be unsupported, the fallback is:
- leave `--` out;
- place the variadic flags before a non-variadic flag;
- reject prompts starting with `-`, with a clear error.

**Verified on 2026-10-01 (task 1.3)** with Claude Code 2.1.286: `claude -p --model haiku --strict-mcp-config --permission-mode plan --add-dir /tmp -- "-v: reply with the word pong" </dev/null` replied `pong` and exited 0. `--` ends option parsing and stops the variadic `--add-dir`, so the argv spec stands and the fallback is not needed.

Values are validated where a bad value would be silently misread: effort level, booleans, the budget (`<->(.<->)#`), and turns (a positive integer). The permission mode is passed through unchanged, so that new Claude Code modes work without a plugin release.

### 7. Resolving the Claude Code command without eval
An array `ZCO_CLAUDE_CMD` is used as is. A string (from the environment or `claude_cmd`) is split with `${(Q)${(z)…}}`, so it follows shell word rules and quotes but runs no expansion or substitution. Then `whence -w` checks the first word:
- `alias` gives an error suggesting a function;
- `none` gives exit 127;
- `function`, `command` and `builtin` are accepted.

The command runs in the current shell, which is why wrapper functions such as `claude-work() { env CLAUDE_CONFIG_DIR=… claude "$@" }` work. Wrapper functions run under our `emulate -L zsh` options, which is harmless for ordinary wrappers and is documented.
- *Alternative:* `eval`. Rejected: an injection surface, and quoting surprises.

### 8. stdin: pass through pipes and files, otherwise /dev/null
`[[ -p /dev/stdin || -f /dev/stdin ]]` covers pipes, `<` redirects, here-strings and process substitution; stdin is passed through. Otherwise the command gets `</dev/null`. This avoids the 3 s stdin wait and keeps Claude Code off the terminal. The same test decides the "prompt, skill or input required" rule, so the two cannot disagree.

### 9. Permission mode `auto` by default; effort only when asked
In `-p` mode nobody can approve a tool call, so anything not allowed is denied silently. A user whose default mode is manual would get runs that "succeed" having done nothing. `auto` lets the classifier approve routine actions and blocks risky ones. `-n` maps to `plan`, which gives the dry run followed by `-c go ahead` workflow.

`--effort` is omitted unless the command line, `ZCO_EFFORT[_<MODEL>]` or a config file sets it. Claude Code's own layered defaults then keep working.

**Haiku rule.** Haiku is detected by `*haiku*` (case-insensitive). The notice is printed only when the effort came from a source meant for this model: the command line, `ZCO_EFFORT_<MODEL>` or a `[model]` section. A global default (`ZCO_EFFORT`, or a file entry outside sections) would otherwise make every haiku call print it.

### 10. Output: plain text by default, stream-json plus jq for progress
Progress runs when `(-v or stderr is a TTY)`, `-q` is not given and `jq` is found. In that case argv gains `--output-format stream-json --verbose` and the run becomes:
```
{ "${cmd[@]}" "${argv[@]}" <stdin-or-devnull } | jq -R -r --unbuffered "$filter" | _zco_route
rc=${pipestatus[1]}
```
jq reads raw lines and tries `fromjson`, so non-JSON lines never abort the stream. It emits one tagged line per event. `_zco_route` is a `while IFS= read -r` loop that runs in the current shell (the last pipeline element), and it dispatches each tag:

| tag | from | routed to |
|---|---|---|
| `P<tool>\t<summary>` | `assistant` → `tool_use` | stderr `→ Tool  summary` (truncated to `$COLUMNS` unless `-v`) |
| `T<line>` | `assistant` → `text` | stderr, `-v` only |
| `R<line>` | `result.result`, one per line, trailing `\n` removed | stdout |
| `E<subtype>` | `result` with `is_error` or `subtype != success` | stderr |
| `S<ms>\t<turns>\t<usd>` | `result` | stderr, `-v` only |
| `X<raw>` | a line that is not JSON | stderr |

Summary fields by tool:
- `Bash`: `command`
- `Read`/`Edit`/`Write`/`NotebookEdit`: `file_path`, relative to `$PWD`
- `Grep`/`Glob`: `pattern`
- `WebFetch`: `url`
- `WebSearch`: `query`
- `Task`/`Agent`: `description`
- `Skill`: `skill`
- any other tool: nothing

Only jq ≥ 1.6 builtins are used, and every field access is optional (`?`, `//`), so schema drift degrades to missing summaries rather than errors. Taking the exit status from `pipestatus[1]` returns Claude Code's status.

**Why jq over pure zsh (resolved 2026-10-01).** Extracting `result` needs a full JSON string decoder. Tool-result events hold whole file contents on one line, which is slow for zsh pattern matching. jq's absence only costs the live progress.

The header is built in `_zco_main`:
- Fields are joined by ` · `. `${(D)PWD}` gives the `~` form of the directory.
- The markers from the run-output spec come next.
- Styling is dim only when `[[ -t 2 ]]` and `NO_COLOR` is unset.
- In a non-UTF-8 locale, ASCII ` - ` and `->` replace `·` and `→`.

### 11. Raw-line capture via `add-zle-hook-widget line-finish`
`_zco_line_finish` is registered with `add-zle-hook-widget line-finish` whenever `_zco_define` created at least one command. The hook is registered even when the default mode is `off`, so that `--literal` and `--shell` keep working. It returns at once unless both of these hold:
- `$CONTEXT == start`, which excludes continuation lines and `vared`.
- The first word is one of our command names, looked up in the global associative array filled by `_zco_define`.

Otherwise it passes the line and the default mode to `_zco_rewrite` and sets `BUFFER` from the result. The default mode is `ZCO_RAW_LINE` if set, else the user file's `raw_line` cached at load, else `literal`; `ZCO_RAW_LINE` is read on every line. Using the documented hook API, not wrapping `accept-line`, lets it compose with oh-my-zsh's direct `zle-line-finish` (kept as hook 0), with zsh-autosuggestions (which ignores `zle-*` widgets) and with zsh-syntax-highlighting in either load order.
- *Alternative:* wrapping `accept-line`. Rejected: it depends on wrap order and on re-wrapping by other plugins.
- *Alternative:* `zshaddhistory` or `preexec`. Rejected: both run after parsing, which is too late.

**`_zco_rewrite` algorithm** (pure: line and default mode in, `REPLY` out, status 0 if changed):
1. Split the line into leading whitespace, the first word and the rest. If the first word is not a command name, the line is unchanged.
2. Tokenise the rest with `${(z)rest}`, which tokenises without expanding anything. Walk the words while keeping a character offset into the raw rest: skip whitespace, then check that the raw text at the offset equals the word, or bail out and leave the line unchanged. Classify the unquoted form `${(Q)word}` with `_zco_classify`, and consume grammar words:
   - `end` and `effort` words;
   - `flag` and `unknown` words, only if the raw word matches `-[A-Za-z0-9_=-]#`. `--shell` and `--literal` among them set the line mode; the last one wins.
   - `value-opt` plus the next word, which may be quoted but must not be a shell operator and must not contain an unterminated quote;
   - `value-eq` words, under the same conditions.

   The first other word is where the prompt starts, and shell operators such as `;`, `|` and `>` start the prompt too.
3. Take the mode from the line flag, else from the default. In mode `off`, the line is unchanged.
4. The rest from the prompt start is R. In `literal` mode the prompt part P is all of R, and the tail T is empty. In `shell` mode, scan R as raw whitespace-separated words, without quote processing; prose apostrophes such as `don't` must not confuse the scan:
   - A word starting with `'` or `"` opens a quoted phrase, which closes at the next word ending with the same character. Words inside a phrase are skipped.
   - The first other word that is exactly one of `|` `|&` `||` `&&` `;` `&` `>` `>>` `>|` `&>` `&>>` `2>` `2>>` `2>&1` `<` splits R. P is the text before it, and T is that word plus everything after it, verbatim.
   - With no such word, P is R and T is empty.
5. Trim P. Nothing changes when any of these holds:
   - P is empty;
   - P holds only safe characters (`[[:alnum:] \t,._:/@%+-]`);
   - P is already exactly one quoted word: `${(z)P}` has one element and P starts with `'`, `"` or `$'` (the idempotence rule).
6. Otherwise `REPLY = <raw prefix up to the prompt start>${(qq)P}`, followed by `" $T"` when T is not empty.

The rewritten line is what zsh shows, runs and saves in history. Recalled lines stay stable because of the idempotence rule, which also covers shell-mode lines: a recalled `opus --shell '…' | pbcopy` has a P that is one quoted word.

**Why shell mode splits only at spaced operators.** Two other split rules were considered and rejected:
- *The zsh lexer (`${(z)}`), finding the first operator token.* Rejected: an apostrophe in prose (`don't`) makes the lexer see one unterminated quote running to the end of the line, so `| pbcopy` would never be found. The lexer also splits at attached operators such as `README.md;`, which cuts prose in the middle.
- *Splitting at any operator character.* Rejected: it would break prompts that mention `<div>`, `a>b` or `x >= y`.

Requiring spaces around the operator makes the split visible, predictable and rare in prose. Users opt in per line or with `raw_line = shell`. `--shell` and `--literal` are long options only, leaving short letters free.

**Self-heal.** The hook sets `_zco_hook_ran=1` on every call. A `preexec` hook checks the flag. If our hook did not run for the line just accepted, the `zle-line-finish` widget has been replaced, so it calls `add-zle-hook-widget` again (which keeps the new widget as hook 0) and clears the flag. Re-registration happens only when our hook provably did not run, so the dispatcher can never end up calling itself.

A structural check at `precmd` was rejected. It cannot tell a clobbering widget from a wrapper that still reaches the dispatcher, like zsh-syntax-highlighting's.

### 12. Completion
`_zco_complete` scans `words[2,CURRENT-1]` with `_zco_classify` and the `_zco_keys` table. It offers:
- options with descriptions (`_describe`) on a `-` prefix;
- effort words while none is set and the prompt has not started;
- values of the option being completed: levels after `-e`, the six modes after `--permission-mode`, `_files` for the file-valued options, `_files -/` for `--add-dir`, nothing for free-text values;
- `_files` once the prompt has started;
- model names for the first argument of `zco`.

It is registered for `zco`, for `_zco_main` (seen when `COMPLETE_ALIASES` is off; the function skips the two leading words) and for each command name (seen when `COMPLETE_ALIASES` is on). If `compdef` is missing at load time, registration moves to a one-shot `precmd` hook.

### 13. Tests: plain zsh scripts, not zunit
- **Runner.** `tests/run.zsh` runs each `tests/**/*.test.zsh` in a fresh `zsh -f`, and each `test_*` function in a subshell. It reports TAP-style output and exits non-zero on failure. `lib/harness.zsh` provides the assertions, temp dirs and a temp `HOME`, so a developer's own `~/.zco.config` never leaks into tests.
- **Why not zunit.** zunit needs its own install plus the revolver dependency and has had no release in years. Plain scripts need nothing beyond zsh and can drive `zpty` directly.
- **Test double.** `tests/bin/claude` is first on `PATH`. It records:
  - argv, NUL-separated;
  - stdin content;
  - the kind of stdin (`tty`, `pipe`, `file`, `chardev`);
  - selected environment variables.

  It prints `$FAKE_CLAUDE_ANSWER` or replays `$FAKE_CLAUDE_STREAM`, and exits with `$FAKE_CLAUDE_EXIT`. The harness refuses to run if `whence -p claude` is not the double.
- **Configuration tests.** Fixture trees are built in the temp `HOME`: user file, nested project files, prompt files. Precedence and source assertions go through `--show-config`; mapping assertions compare the exact argv.
- **TTY and ZLE.** `lib/pty.zsh` drives `zsh -i` under `zpty`. It covers terminal detection, the raw-line end-to-end flows, coexistence and completion. This is the end-to-end layer: a real interactive shell and a real typed line, down to the recorded argv.
- **Hiding jq.** "Without jq" runs use a `PATH` holding only symlinks to the tools the double needs.

### 14. Coverage stand-in, lint and CI
No maintained tool measures line coverage for zsh. Coverage is measured instead as **spec-scenario coverage**. Each test carries `# @scenario <capability>: <Scenario name>`, and `tests/scenario-coverage.zsh` fails when any `#### Scenario:` has no test. The target is 100%.

`tests/run.zsh --lint` runs `zsh -n` on every zsh file. A hygiene check scans tracked files and fails on absolute home paths and on AI attribution trailers or "generated with" notes. Lines that only describe these patterns carry an allow-marker. <!-- hygiene: allow -->

**CI** (`.github/workflows/ci.yml`) has:
- An `ubuntu-latest` and `macos-latest` matrix running lint, the full suite, hygiene and scenario coverage.
- A `zshusers/zsh:5.3.1` container job for the minimum version. If jq cannot be installed there, that job exercises the fallback without jq.
- Coexistence plugins cloned at pinned tags into `tests/.deps/`, which is gitignored.

*Implementation notes (2026-10-01):*
- The minimum-version job runs the `zshusers/zsh:5.3.1` image with `docker run` on an Ubuntu runner rather than as a `container:` job, because `actions/checkout` needs a Node runtime that the image is too old for.
- The pinned tags are zsh-syntax-highlighting 0.8.0 and zsh-autosuggestions v0.7.1 (`tests/fetch-deps.zsh`).
- The full suite was run locally on a zsh 5.3.1 built from source as well as on 5.9.
- The runner unsets `FPATH`, so each zsh uses its own function library rather than one inherited from the environment.
- On zsh 5.3, zsh-autosuggestions shows no suggestion next to zsh-syntax-highlighting even without this plugin. The coexistence tests therefore compare against a baseline run without zsh-claude-oneshot.

**Smoke test.** `tests/smoke/real-claude.test.zsh` runs only with `ZCO_SMOKE=1` and is never run in CI. It covers two things:
- Parse-time checks through `</dev/null` probes, with no API call: the hidden flags are still accepted, `--skill` is still unknown, and a missing agent is rejected.
- A few haiku calls: the `--` separator with a variadic flag, `auto` and `plan` accepted, the stream-json field names, and start-up time.

**Smoke test results, 2026-10-01 (task 10.2), Claude Code 2.1.286:** all seven checks passed.
- `--system-prompt-file`, `--append-system-prompt-file` and `--max-turns` are still accepted; `--skill` is still unknown; a missing agent is rejected before any API call.
- `zco haiku --add-dir /tmp -- '-v: …'` answers the prompt, so `--` still stops the variadic flag.
- `auto` and `plan` are accepted.
- The stream-json fields read by the jq filter are present: `assistant` events with `message.content[]` items of type `text` and `tool_use` (`name`, `input`), and a `result` event with `subtype`, `result`, `duration_ms`, `num_turns` and `total_cost_usd`. The stream also carries `system` hook events, `rate_limit_event` and `thinking` content items, which the filter ignores as designed.
- Which tools exist depends on the user's Claude Code setup: in the tested setup `Glob` was not available, so the smoke test asks for any read-only tool call instead of a specific tool.
- A trivial haiku prompt through `zco` took 2.9 to 3.0 s, in line with the 2.8 s measured earlier.

### 15. Repository hygiene
- `.gitignore`: `.claude/`, `tests/.deps/`, `.DS_Store`. `.zco.config` is not ignored, because a project may choose to commit one.
- `openspec/` is committed.
- Examples use generic names only (`claude-work`, `reviewer`, `~/proj`).

## Risks / Trade-offs

- **`auto` permission mode may be unavailable** for some accounts, providers or models. → The README explains the mode and shows `permission_mode = acceptEdits`, and the smoke test checks acceptance.
- **Plan mode in `-p` may behave differently** from interactive plan mode. → The smoke test checks that `-n` yields a plan as its final answer.
- **`--` may not end Claude Code's option parsing,** or may not stop variadic flags. → Verified early (task 1.3), with the fallback from Decision 6.
- **Hidden flags may change or disappear.** `--system-prompt-file`, `--append-system-prompt-file` and `--max-turns` are not in `--help`. → The smoke test's no-prompt probes catch this without an API call.
- **Claude Code may add a real skill flag later.** → Only the argv mapping in Decision 5 changes; the spec'd behaviour (the prompt runs the skill) stays.
- **A config typo breaks every run.** → The error names `file:line`, and `--show-config` shows what is in effect. This is deliberate, so that a typo never silently changes a run.
- **Project files can surprise.** A repository may set an agent, a system prompt or tool rules. → The header shows `· local config`, `--show-config` names the file, `ZCO_LOCAL_CONFIG=0` turns lookup off, and restricted keys cannot run programs.
- **`--system-prompt` replaces Claude Code's default system prompt,** including its tool guidance. → The README recommends `append_system_prompt` for house style and reserves replacement for special cases.
- **The `extra_args` filter can lag behind new Claude Code flags.** → The filter is limited to the user file, and the never-pass list is maintained with the smoke test.
- **Raw-line capture changes shell semantics after a model command.** In the default literal mode, `>`, `|`, `;` and `$(…)` become prompt text. → Documented, with escape routes: `--shell` for pipes and redirections on one line, `raw_line = shell` as a default, pipes into the command, `zco … > file` and `raw_line = off`.
- **Shell mode can split at a spaced operator meant as prose** (`is a > b true`). → Shell mode is opt-in, the split needs spaces on both sides, the rewritten line is shown as it runs, and `--literal` overrides for one line.
- **History holds the quoted form** of rewritten lines. → The rewrite is idempotent and rewrites only when needed.
- **The stream-json schema can drift** between Claude Code versions. → Optional field access in jq, fixtures and the smoke test.
- **A plugin that replaces `zle-line-finish` after us** lets one line through without the rewrite before the self-heal kicks in. → Documented; coexistence tests cover the common plugins.
- **Load-time warnings conflict with Powerlevel10k instant prompt.** → Warnings appear only on misconfiguration.
- **`-c` continues the most recent session in the directory,** which may be an interactive one. → Documented next to `-c`, with `-r ID` as the precise alternative.
- **Workspace trust is skipped by `-p`.** → A security note in the README. The header shows the directory, and `· local config` shows when a project file applies.
- **Scenario coverage is not line coverage.** → Each scenario is required to have a test, and the pure functions get extra unit cases beyond the scenarios.

## Migration Plan

This is a new project, so there is nothing to migrate. Revision 1.0.0 of this change had `ZCO_NO_SESSION_PERSISTENCE`; nothing was implemented under that name.

**Release.** Tag `v0.1.0` after CI passes on both operating systems and the user approves pushing.

**Rollback.** Remove the plugin line and open a new shell. The only state is the user's own `.zco.config` files, which are simply ignored once the plugin is gone.

## Open Questions

- The exact wording of help text, notices and `--show-config` comments. It can change without affecting specs or tasks.
- Summaries for tools not listed in Decision 10, such as MCP tools. These show without a summary until someone asks for one.
- Possible follow-ups:
  - named presets in `.zco.config` (e.g. `[preset.review]` selected with an option);
  - completion of agent, skill and slash-command names.
