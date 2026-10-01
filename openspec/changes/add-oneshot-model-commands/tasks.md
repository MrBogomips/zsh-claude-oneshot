# Tasks

## 1. Repository setup and early checks

- [x] 1.1 Initialise the git repository on branch `main`. Add `.gitignore` with `.claude/`, `tests/.deps/` and `.DS_Store`. Verify that `git status --ignored` shows `.claude/` as ignored and `openspec/` as untracked.
- [x] 1.2 Confirm that the brief's working names are gone. Verify that `grep -rnE 'CQ_|_cq\b'` over the repository finds nothing.
- [x] 1.3 After the user OKs it, make one real haiku call: `claude -p --model haiku --strict-mcp-config --permission-mode plan --add-dir /tmp -- "-v: reply with the word pong" </dev/null`. It checks two things: that `--` ends Claude Code's option parsing, and that it stops the variadic `--add-dir`. Verify that the reply answers the prompt instead of treating it as `-v` or as a directory, and record the result in design.md Decision 6. If either check fails, switch the claude-invocation argv spec and the affected scenarios to the Decision 6 fallback before continuing.
- [x] 1.4 Add an MIT `LICENSE`. The copyright holder is "the zsh-claude-oneshot contributors" unless the user names one. Verify that the file has the correct license text and no personal name or email.
- [x] 1.5 Create the skeleton of `zsh-claude-oneshot.plugin.zsh`: self-location with the Zsh Plugin Standard `$0` idiom plus `:A`, `fpath`, and `autoload -Uz` of `functions/*`. Verify that `zsh -n` passes and that `zsh -f -c 'source ./zsh-claude-oneshot.plugin.zsh'` exits 0 with no output.

## 2. Test harness

- [x] 2.1 Write `tests/lib/harness.zsh` and `tests/run.zsh`.
  - The harness provides the assertions `assert_eq`/`assert_argv`/`assert_contains`/`assert_status`, temp dirs, a temp `HOME` and `PATH` set-up, and plugin loading.
  - The runner discovers `**/*.test.zsh`, runs one `zsh -f` per file and one subshell per test, prints TAP-style output and sets the exit status.

  Verify with `tests/self/harness.test.zsh`: running the runner on a fixture directory with one passing and one failing test reports both, and the runner exits 1. Also verify that a `~/.zco.config` in the real home is never read.
- [x] 2.2 Write the Claude Code test double `tests/bin/claude`. It records argv NUL-separated, the stdin content, the stdin kind and selected environment variables. It prints `$FAKE_CLAUDE_ANSWER`, or replays `$FAKE_CLAUDE_STREAM` when asked for `stream-json`, and exits with `$FAKE_CLAUDE_EXIT`. Verify with `tests/self/fake-claude.test.zsh` that arguments containing spaces and newlines are recorded exactly and that `pipe`, `file` and `chardev` stdin are told apart.
- [x] 2.3 Add the harness guard that aborts the run when `whence -p claude` is not the test double. Verify by putting another `claude` first on `PATH` and checking that the runner aborts before any test runs.
- [x] 2.4 Write `tests/lib/pty.zsh`. It starts `zsh -i` under `zpty` with a test `ZDOTDIR`, types a line, waits for a marker and returns the output. Verify with a self-test that typing `print -r -- ok` returns `ok`.
- [x] 2.5 Add `tests/run.zsh --lint`, which runs `zsh -n` on every zsh file. Verify that it fails on a fixture with a syntax error and passes on the repository.
- [x] 2.6 Write `tests/scenario-coverage.zsh`. It matches `# @scenario <capability>: <name>` tags against the `#### Scenario:` headings in the change specs and main specs. Verify that it names an untagged scenario from a fixture spec and exits non-zero.
- [x] 2.7 Write `tests/check-hygiene.zsh`. It fails on absolute home paths (`/Users/`, `/home/`), on AI attribution trailers and on "generated with" notes in tracked files. It skips lines that only describe its own patterns, using an explicit allow-marker. Verify that it flags a fixture line and passes on the repository. <!-- hygiene: allow -->

## 3. Prompt grammar and key schema

- [ ] 3.1 Write unit tests for `_zco_keys`, `_zco_classify` and `_zco_parse`, tagged `# @scenario prompt-grammar: …`. Cover every prompt-grammar scenario that does not depend on stdin, including "Option values" and "Line-mode options at run time". Add these edge tokens:
  - bare `-`;
  - empty `--effort=` and `--agent=`;
  - a value option as the last token;
  - bundles that contain a value option;
  - repeated list options.

  Verify that they fail.
- [ ] 3.2 Implement `_zco_keys`, the single schema for every key: type, command-line option, environment name, list or scalar, and whether it is user-file only. Verify with a unit test that it matches the key table in the configuration spec row by row.
- [ ] 3.3 Implement `_zco_classify` with the token classes from design Decision 3, reading the value-option names from `_zco_keys`. Verify that its unit tests pass.
- [ ] 3.4 Implement `_zco_parse`:
  - the effort-once rule and the `-e`/`--effort`/`--effort=` forms;
  - value options in both `--opt VALUE` and `--opt=VALUE` form, with list options accumulating;
  - `--`, bundles, and last-wins for `-v`/`-q`;
  - the ultracode rule, unknown options and missing values.

  Verify that the parser tests pass.
- [ ] 3.5 Implement `_zco_usage` and `_zco_err`. Usage errors go to stderr, are prefixed with the command name and exit with status 2; help goes to stdout, lists every option from `_zco_keys` and exits with status 0. Verify that the "Help" and "Usage errors" scenarios pass.
- [ ] 3.6 Write the README skeleton:
  - intro and quick examples;
  - grammar, the options table generated from the same list as `_zco_keys`, and effort words;
  - `--` and the ultracode note;
  - reusable prompts through Claude Code slash commands and skills (`haiku -s prepare-commit`, or `haiku /prepare-commit`), with no recipes shipped;
  - related projects, and what sets this plugin apart.

  Verify that each example in the grammar section has a matching parser test.

## 4. Configuration files

- [ ] 4.1 Write tests for every configuration scenario, using fixture trees in the temp `HOME`: a user file, nested project files and prompt files. Add parser edge cases:
  - a missing final newline;
  - `=` inside a value;
  - an empty value;
  - `#` inside a value, which stays literal;
  - CRLF line endings;
  - a section header with surrounding spaces.

  Verify that they fail.
- [ ] 4.2 Implement `_zco_config_find`: `ZCO_CONFIG` or `~/.zco.config`, the walk up to the nearest project file (not counting the user file) and the `ZCO_LOCAL_CONFIG` switch. Verify that the discovery scenarios pass.
- [ ] 4.3 Implement `_zco_config_read`:
  - the line loop with line numbers, sections, trimming and outer-quote removal, with nothing evaluated;
  - key and type validation against `_zco_keys`;
  - refusal of user-only keys and `bypassPermissions` in the project file;
  - relative-path resolution against the file's directory, and `~/` expansion.

  Verify that the format, validation, restricted-keys and relative-path scenarios pass, including "No evaluation".
- [ ] 4.4 Implement `_zco_config_get`: the seven layers, `ZCO_<KEY>` and `ZCO_EFFORT_<MODEL>`, list replacement plus command-line append, and source tracking. Verify that the precedence, list-key, "Scalar key through the environment" and "Editing a file between runs" scenarios pass.
- [ ] 4.5 Implement `_zco_config_show`. Its INI-style output carries `# source` comments and header comments naming the files found. Verify its output directly for the two "Showing the effective configuration" scenarios; the command-line wiring is task 5.7.
- [ ] 4.6 Document `.zco.config` in the README:
  - locations and format;
  - precedence;
  - the key table;
  - the keys restricted to the user file, and why;
  - `--show-config`;
  - an example user file and an example project file.

  Verify that both README example files parse without errors in a test, and that the README key table matches `_zco_keys`.

## 5. Claude Code invocation and curated options

- [ ] 5.1 Write tests that run through `zco` and the test double. Cover every claude-invocation and claude-options scenario, plus the prompt-grammar scenarios "Nothing to send" and "Piped input without a prompt". Verify that they fail.
- [ ] 5.2 Implement `_zco_cmd`: `ZCO_CLAUDE_CMD` as an array or string, or `claude_cmd` from the user file; the `${(Q)${(z)…}}` split; `whence -w` checks; an alias error; and 127 when the command is missing. Verify that the command-resolution scenarios pass, including "Command from the user file" and the no-evaluation case.
- [ ] 5.3 Implement `_zco_effort`: the effective effort across all layers, value validation with the source named, and the haiku rule that prints the notice only for model-specific sources. Verify that the effort and haiku scenarios pass, including "Haiku section with effort".
- [ ] 5.4 Implement `_zco_bool` and the core of `_zco_argv`:
  - the fixed 19-position order;
  - permission-mode precedence, with `-n` winning;
  - MCP, and `--continue` or `--resume` (a usage error when both are given);
  - persistence, the budget and the turn limit.

  Verify that the exact-argv, permission-mode, MCP, persistence, budget, turn-limit and resume scenarios pass.
- [ ] 5.5 Add the curated options to `_zco_argv`:
  - agent;
  - the skill prompt prefix, with name validation;
  - the system-prompt groups, with the file-readability check;
  - list pairs;
  - settings, fallback model, and `--mcp-config` together with `--strict-mcp-config`.

  Verify that the agent, skill, system-prompt, directory and tool-rule, and MCP-configuration scenarios pass.
- [ ] 5.6 Implement the `extra_args` filter: never-pass flags, managed flags in plain and `--flag=value` form, and short-option bundles. Verify that the three extra-arguments scenarios pass, plus unit cases for `--effort=high`, `-pc` and `--dangerously-skip-permissions=true`.
- [ ] 5.7 Implement `_zco_main` for text mode:
  - parse, load the configuration and resolve settings;
  - validate, then detect stdin and redirect to `/dev/null` when it is not a pipe or file;
  - handle the `--show-config` path;
  - run in the current shell and return the exit status.

  Verify that the stdin, exit-status and "Showing the effective configuration" scenarios pass end to end, with the terminal-stdin case driven through `zpty`.
- [ ] 5.8 Add a property test that runs every combination of `-n -c -m -v -q`, effort sources, boolean settings and a set of `extra_args` values. Verify that no forbidden flag (`--bare`, `--safe-mode`, `--dangerously-skip-permissions`, `--allow-dangerously-skip-permissions`) is ever passed, and that every run carrying a forbidden `extra_args` value fails with status 2.
- [ ] 5.9 Document in the README:
  - `ZCO_CLAUDE_CMD` / `claude_cmd`, with wrapper functions (e.g. `claude-work`) and multi-word commands;
  - the permission modes, and what `auto` means in `-p` mode;
  - the `-n` then `-c` workflow, with the note that `-c` may continue an interactive session and `-r ID` as the precise alternative;
  - the haiku effort rule;
  - MCP skipped for fast start, and `--mcp-config`;
  - the curated options table;
  - `-s` versus writing `/skill` yourself;
  - the advice to append to the system prompt rather than replace it;
  - `extra_args`;
  - the security note on workspace trust and project files.

  Verify that every option and variable in the README appears in `_zco_usage` output and in at least one test.

## 6. Plugin loading and per-model commands

- [ ] 6.1 Write tests for every model-commands scenario. Verify that they fail.
- [ ] 6.2 Complete the entry file: the `is-at-least 5.3` check, quiet loading, idempotent re-sourcing, and the load-time keys `models`, `prefix` and `raw_line` read from the environment or the user file. Verify that these scenarios pass: "Sourced from another directory", "Sourced through a symlink", "Sourced twice", "Old zsh" (via a shadowed `is-at-least`) and "Model list from the user file".
- [ ] 6.3 Implement `_zco_define`:
  - the model list as an array or a string, with an empty value as opt-out;
  - the prefix;
  - name validation;
  - collision checks that recognise the plugin's own aliases;
  - `noglob _zco_main <name> <model>` aliases;
  - the global table of command names used by the rewrite.

  Verify that the command-definition, prefix, opt-out, collision and invalid-entry scenarios pass.
- [ ] 6.4 Implement `zco`. Verify that the zco scenarios pass, including the redirect-to-file case.
- [ ] 6.5 Check glob safety and independence from user options. Run the model-commands, claude-invocation and configuration tests again under `setopt KSH_ARRAYS SH_WORD_SPLIT NO_UNSET ERR_EXIT EXTENDED_GLOB NULL_GLOB`. Verify that the recorded argv is identical and that `setopt` output is the same before and after a run. Also check that the "Configuration sources" boolean scenarios pass.
- [ ] 6.6 Document installation in the README: oh-my-zsh custom plugin, antidote, zinit, zap and manual `source`, plus `models` / `prefix` and the opt-out. Verify that the manual `source` snippet works in a `zsh -f` test, and check the plugin-manager snippets against each manager's documented syntax.

## 7. Output and live progress

- [ ] 7.1 Write synthetic stream-json fixtures in `tests/fixtures/`:
  - a tool call for each tool summarised in design Decision 10;
  - text blocks;
  - a success result and a multi-line result;
  - an `error_max_budget_usd` result;
  - one deliberate non-JSON line.

  Verify that every fixture line except the deliberate one passes `jq -e .`.
- [ ] 7.2 Write tests for every run-output scenario, with the terminal cases driven through `zpty`. Verify that they fail.
- [ ] 7.3 Implement the header:
  - fields, with `settings` / `n/a` for the effort, and the `~` directory form;
  - the markers `continue`/`resume`, `agent <name>`, `/<skill>`, `mcp` and `local config`;
  - dim styling, `NO_COLOR`, and the ASCII fallback outside UTF-8 locales;
  - no header for `-q`, `-h` and `--show-config`.

  Verify that the header and styling scenarios pass, including "Agent, skill and project file".
- [ ] 7.4 Implement `_zco_render` and `_zco_route`: the jq filter from design Decision 10, tag routing, truncation to `$COLUMNS`, the `-v` extras, and the exit status from `pipestatus[1]`. Verify that these scenarios pass: progress, verbose, error result, non-JSON line, and "Same answer in both modes".
- [ ] 7.5 Implement the choice of output mode (stderr a terminal, `-v`, `-q`, jq present) and the missing-jq notice. Verify that the quiet, "stderr not a terminal" and missing-jq scenarios pass with jq hidden from `PATH`.
- [ ] 7.6 Document output in the README: stdout versus stderr, the header fields and markers, progress, `-v`/`-q`, jq being optional, and `NO_COLOR`. Verify that the header examples in the README match the test expectations.

## 8. Raw-line capture

- [ ] 8.1 Write unit tests for `_zco_rewrite` in all three modes. Cover every raw-line-capture scenario that rewrites or leaves a line alone, including "Quoted option value before an unquoted prompt" and the "Shell mode" scenarios. Add these edge cases:
  - tabs and trailing spaces;
  - `$'…'` input;
  - value options followed by an unsafe or unterminated-quote value;
  - `--opt='quoted value'`;
  - shell operators right after the options;
  - embedded newlines;
  - prefixed command names.

  For shell mode, also cover:
  - every operator in the split list;
  - an operator as the last word;
  - attached operators (`a>b`, `README.md;`, `<div>`);
  - an unclosed quoted phrase;
  - `--shell` inside the prompt, which is not a flag there;
  - `--shell` followed by `--literal`, and the reverse order.

  Add an idempotence property: rewriting the rewrite leaves it unchanged, in every mode. Verify that they fail.
- [ ] 8.2 Implement `_zco_rewrite` with the `${(z)}` word walk, raw offsets, mode selection and the shell-mode split scan from design Decision 11. Verify that its unit tests pass.
- [ ] 8.3 Implement `_zco_line_finish` and its registration: `add-zle-hook-widget line-finish` whenever at least one command is defined, the `CONTEXT` guard, and the default mode from `ZCO_RAW_LINE`, the cached user-file `raw_line` or `literal`. An invalid value triggers the load-time warning. Verify end to end through `zpty` that these scenarios pass:
  - apostrophe and redirection, separators, expansion characters, multi-line prompt and quoted option value;
  - history form and continuation line;
  - every "Line modes" scenario;
  - piping, redirecting and chaining in shell mode.

  Each test asserts the argv recorded by the double, the content received by the pipe or file, and that no stray files appear.
- [ ] 8.4 Implement the `preexec` self-heal. Verify the "Widget replaced later" scenario through `zpty`, including that the replacing widget still runs.
- [ ] 8.5 Add the coexistence tests:
  - an oh-my-zsh-style `zle-line-finish` defined before loading;
  - zsh-syntax-highlighting and zsh-autosuggestions at pinned tags, loaded before and after the plugin.

  Verify that all orders pass, and that the tests skip with a notice when `tests/.deps/` is absent.
- [ ] 8.6 Document raw-line capture in the README:
  - what gets quoted, and that option values keep normal shell quoting;
  - when lines are left alone, and the form stored in history;
  - that `$VAR`, `$(…)` and `>` become prompt text in literal mode;
  - `--shell` for pipes, redirections and `&&` on one line, with the spaced-operator rule and the quoted-phrase rule;
  - `--literal`, and the `raw_line = literal | shell | off` default;
  - the other escape routes: `zco`, `{ … }` and pipes into the command;
  - the recommended load order.

  Verify that each documented example has a matching rewrite test.

## 9. Tab completion

- [ ] 9.1 Write completion tests through `zpty` for every shell-completion scenario: short and long options (including `--shell` and `--literal`), effort words, `-e` levels, permission modes, `--add-dir` directories, files inside the prompt, models for `zco`, `compinit` run after loading, and `COMPLETE_ALIASES` on. Verify that they fail.
- [ ] 9.2 Implement `_zco_complete`, driven by `_zco_classify` and `_zco_keys`, and register it for `zco`, `_zco_main` and each command name, deferring registration to `precmd` when `compdef` is missing. Verify that the completion tests pass.
- [ ] 9.3 Mention completion in the README usage section. Verify that the completions listed there match the tests.

## 10. CI and integration checks

- [ ] 10.1 Add `.github/workflows/ci.yml` with:
  - an Ubuntu and macOS matrix running lint, the full suite, the hygiene check and scenario coverage;
  - the `zshusers/zsh:5.3.1` container job;
  - pinned clones of the coexistence plugins into `tests/.deps/`.

  Verify with `actionlint` if available, and by running the same commands locally on macOS.
- [ ] 10.2 Write `tests/smoke/real-claude.test.zsh`, gated by `ZCO_SMOKE=1`.
  - No-prompt parse-time probes, with no API call: the hidden flags are still accepted, `--skill` is still unknown, and a missing agent is rejected.
  - A few haiku calls: the `--` separator with a variadic flag, `auto` and `plan` accepted, the stream-json field names read by the jq filter, and fast-start timing.

  Verify that it is skipped by default. Run it once with the user's approval and record the results in design.md.
- [ ] 10.3 Run the full local gate: `zsh tests/run.zsh --lint && zsh tests/run.zsh && zsh tests/scenario-coverage.zsh && zsh tests/check-hygiene.zsh`. Verify that every spec scenario is covered and all checks pass.
- [ ] 10.4 After the user explicitly approves, create the public repository (`gh repo create MrBogomips/zsh-claude-oneshot --public`) and push. Verify that CI passes on Ubuntu, macOS and the minimum-zsh job.
