# zsh-claude-oneshot

One-shot [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) prompts from zsh.
The model is the command, and the prompt is typed without quotes:

```zsh
opus commit local changes
sonnet edit README.md: add an install section, don't touch the license
haiku -n reorg this folder by year      # dry run: Claude Code only plans
haiku -c go ahead                       # then continue the same session
git diff | haiku summarize for a changelog
```

Each command runs `claude -p` in the current directory with the model you named. Your
CLAUDE.md files, hooks and permission rules stay in force. The final answer goes to stdout, so
it can be piped or redirected. A one-line header and live progress go to stderr:

```text
opus · xhigh · auto · ~/proj
→ Bash  git status --short
→ Bash  git diff --stat
Committed 3 files: "docs: add install section"
```

- [Install](#install)
- [Usage](#usage)
- [Configuration files](#configuration-files)
- [How Claude Code is run](#how-claude-code-is-run)
- [Output](#output)
- [Typing prompts without quotes](#typing-prompts-without-quotes)
- [Completion](#completion)
- [Security](#security)
- [Related projects](#related-projects)

## Install

Requirements: zsh 5.3 or newer and Claude Code (`claude` on your `PATH`). `jq` is optional;
it is only needed for live progress.

```zsh
git clone https://github.com/MrBogomips/zsh-claude-oneshot ~/src/zsh-claude-oneshot
echo 'source ~/src/zsh-claude-oneshot/zsh-claude-oneshot.plugin.zsh' >> ~/.zshrc
```

## Usage

### Grammar

```text
<model> [effort] [options] [--] prompt…
zco <model> [effort] [options] [--] prompt…
```

There is one command per model: `fable`, `opus`, `sonnet` and `haiku` by default. Options and
an effort word come first, in any order. The first other word starts the prompt, and everything
from there on is prompt text, even words that look like options:

<!-- grammar-examples:start -->
```zsh
opus commit local changes                 # prompt only; effort left to your settings
opus xhigh commit local changes           # effort word first
opus -n high reorg this folder            # options and effort in any order...
opus high -n reorg this folder            # ...both mean the same
opus explain what -n does in grep         # -n after the prompt start is prompt text
opus high high level overview             # only the first effort word counts
opus -e max high level overview           # an effort set by -e makes "high" prompt text
sonnet --effort=low fix the typo          # long options also take =VALUE
opus -nc go ahead                         # options without a value can be bundled
opus --agent reviewer high check this     # an option value is the next word
opus --system-prompt='Be terse.' summarize
opus -- high level overview of this repo  # after --, everything is prompt text
opus -- -v prints nothing, why?
```
<!-- grammar-examples:end -->

`zco` takes the model as its first argument. Use it in scripts, for models whose names are not
valid command names (`zco 'opus[1m]' …`), or when you opted out of the per-model commands.
`zco` follows normal shell quoting, so quote the prompt there.

### Effort

The effort word is one of `low`, `medium`, `high`, `xhigh` and `max`, in lower case, before the
prompt. `-e LEVEL` and `--effort LEVEL` do the same. Without either, no `--effort` is passed and
Claude Code's own effort settings apply. Haiku does not take an effort; see
[How Claude Code is run](#how-claude-code-is-run).

### Options

<!-- options-table:start -->
| Option | Value | Meaning |
|---|---|---|
| `-n`, `--dry-run` | — | dry run: plan permission mode, nothing is changed |
| `-c`, `--continue` | — | continue the most recent session in this directory |
| `-m`, `--mcp` | — | include MCP servers |
| `-v`, `--verbose` | — | more progress output |
| `-q`, `--quiet` | — | no header, progress or notices |
| `-h`, `--help` | — | print this help |
| `--show-config` | — | print the effective configuration and exit |
| `--shell` | — | typed line: the prompt ends at a spaced shell operator |
| `--literal` | — | typed line: the whole rest of the line is the prompt |
| `-e`, `--effort` | `LEVEL` | effort level: low medium high xhigh max |
| `-a`, `--agent` | `NAME` | run as this Claude Code agent |
| `-s`, `--skill` | `NAME` | start the prompt with /NAME (a skill or slash command) |
| `-r`, `--resume` | `ID` | resume the session with this id |
| `--permission-mode` | `MODE` | permission mode (default auto) |
| `--system-prompt` | `TEXT` | replace the system prompt |
| `--system-prompt-file` | `PATH` | replace the system prompt with a file |
| `--append-system-prompt` | `TEXT` | append text to the system prompt |
| `--append-system-prompt-file` | `PATH` | append a file to the system prompt |
| `--add-dir` | `DIR` | let Claude Code use another directory (repeatable) |
| `--allowed-tools` | `RULE` | allow a tool rule (repeatable) |
| `--disallowed-tools` | `RULE` | deny a tool rule (repeatable) |
| `--settings` | `VALUE` | settings file or JSON |
| `--mcp-config` | `PATH` | load MCP servers from this file (repeatable) |
| `--fallback-model` | `MODEL` | model to use when the main one is overloaded |
| `--max-turns` | `N` | stop after N agentic turns |
| `--max-budget-usd` | `AMOUNT` | stop when the cost exceeds AMOUNT dollars |
| `--` | — | end of options: everything after it is the prompt |
<!-- options-table:end -->

### `--` and ultracode

`--` ends the options: everything after it is prompt text, including words that look like
options or effort words. Use it when the prompt starts with a dash or with an effort word.

`ultracode` is refused as an effort level and as the first word of a prompt. Claude Code reads
that keyword as consent to start multi-agent workflows, which a one-shot command should never
start by accident. If you mean the word, put `--` before the prompt: `opus -- ultracode …`.

### Reusable prompts: slash commands and skills

zsh-claude-oneshot ships no prompt recipes. Reusable prompts belong in Claude Code itself, as
[slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands) or
[skills](https://docs.claude.com/en/docs/claude-code/skills), where every Claude Code session can
use them. Run one with `-s`, or write the slash command yourself:

```zsh
haiku -s prepare-commit                   # the prompt is /prepare-commit
haiku /prepare-commit                     # the same, written out
sonnet -s review focus on the tests       # the prompt is /review focus on the tests
```

## Configuration files

Defaults that repeat across runs live in configuration files rather than on every command line:
the permission mode, the effort per model, a house style for the system prompt, an agent for one
repository, tool rules, extra directories.

### Locations

- **User file:** `~/.zco.config`, or the file named by `ZCO_CONFIG`.
- **Project file:** the nearest `.zco.config` in the current directory or one of its parents.
  Only the nearest one applies, and `~/.zco.config` is never a project file. Set
  `ZCO_LOCAL_CONFIG=0` to ignore project files.

A missing file is ignored. Both files are read at every run, so an edit takes effect at the next
command. The exceptions are `models`, `prefix` and `raw_line`, which are read from the user
file once, when the plugin loads.

### Format

<!-- example-format-config:start -->
```ini
# Comments are whole lines that start with # or ;
effort = medium
append_system_prompt = "Use # for headings. "

[opus]
; entries from here on apply only when opus runs
effort = xhigh
```
<!-- example-format-config:end -->

- One `key = value` entry per line; spaces around the key, the `=` and the value are ignored.
- A line `[model]` starts a section for that model. Entries before the first section apply to
  every model.
- A `#` or `;` later in a line is part of the value; only whole lines are comments.
- One pair of matching quotes around the whole value is removed, which keeps outer spaces.
  Nothing else is processed: no escapes, no variables, no command substitution. The file is
  never executed.
- In path values, a leading `~/` means your home directory, and a relative path is relative to
  the directory of the file that contains it.
- An unknown key, a malformed line or an invalid value stops the run with an error naming the
  file and line, so a typo can never silently change what a run does.

### Precedence

From lowest to highest; the highest layer that sets a value wins:

1. built-in default
2. user file
3. user file, section of the running model
4. project file
5. project file, section of the running model
6. environment: `ZCO_<KEY>` for scalar keys, and `ZCO_EFFORT_<MODEL>` above `ZCO_EFFORT`
7. command line

Within one file, a later line wins. List keys work by layer: repeated lines add entries in order,
a layer that sets a list replaces the lists of lower layers, `key =` with no value empties the
list, and values given on the command line are appended. The text and file forms of a system
prompt (`system_prompt` and `system_prompt_file`, and the two `append_` keys) count as one
setting: the higher layer wins, whichever form it uses.

`ZCO_EFFORT_<MODEL>` uses the model name in upper case, with any character other than letters,
digits and `_` replaced by `_`: `ZCO_EFFORT_OPUS`, `ZCO_EFFORT_CLAUDE_SONNET_4_5`.
Boolean values accept `1`, `true`, `yes`, `on` and `0`, `false`, `no`, `off`, in any case.

### Keys

<!-- keys-table:start -->
| Key | Meaning | Default | Command line | Environment | Project file |
|---|---|---|---|---|---|
| `models` | model names separated by whitespace, one command each | `fable opus sonnet haiku` | — | `ZCO_MODELS` | no |
| `prefix` | prefix for the command names, e.g. c- for c-opus | — | — | `ZCO_PREFIX` | no |
| `raw_line` | interactive line mode: literal, shell or off | `literal` | `--literal`, `--shell` | `ZCO_RAW_LINE` | no |
| `claude_cmd` | Claude Code command words; quotes are honoured, nothing is expanded | `claude` | — | `ZCO_CLAUDE_CMD` | no |
| `extra_args` | one more Claude Code argument per line | — | — | — (list) | no |
| `mcp_config` | MCP configuration file, one per line | — | `--mcp-config` | — (list) | no |
| `permission_mode` | permission mode (bypassPermissions only in the user file) | `auto` | `--permission-mode`, `-n` | `ZCO_PERMISSION_MODE` | yes, except `bypassPermissions` |
| `effort` | effort level: low, medium, high, xhigh or max | — | `-e`, `--effort` | `ZCO_EFFORT` | yes |
| `mcp` | include the MCP servers Claude Code is configured with | `false` | `-m`, `--mcp` | `ZCO_MCP` | yes |
| `session_persistence` | save sessions, so -c and -r can pick them up | `true` | — | `ZCO_SESSION_PERSISTENCE` | yes |
| `max_budget_usd` | stop when the cost exceeds this many dollars | — | `--max-budget-usd` | `ZCO_MAX_BUDGET_USD` | yes |
| `max_turns` | stop after this many agentic turns | — | `--max-turns` | `ZCO_MAX_TURNS` | yes |
| `agent` | Claude Code agent to run as | — | `-a`, `--agent` | `ZCO_AGENT` | yes |
| `system_prompt` | text that replaces the system prompt | — | `--system-prompt` | `ZCO_SYSTEM_PROMPT` | yes |
| `system_prompt_file` | file that replaces the system prompt | — | `--system-prompt-file` | `ZCO_SYSTEM_PROMPT_FILE` | yes |
| `append_system_prompt` | text appended to the system prompt | — | `--append-system-prompt` | `ZCO_APPEND_SYSTEM_PROMPT` | yes |
| `append_system_prompt_file` | file appended to the system prompt | — | `--append-system-prompt-file` | `ZCO_APPEND_SYSTEM_PROMPT_FILE` | yes |
| `add_dir` | another directory Claude Code may use, one per line | — | `--add-dir` | — (list) | yes |
| `allowed_tools` | tool rule to allow, one per line | — | `--allowed-tools` | — (list) | yes |
| `disallowed_tools` | tool rule to deny, one per line | — | `--disallowed-tools` | — (list) | yes |
| `settings` | settings file or JSON | — | `--settings` | `ZCO_SETTINGS` | no |
| `fallback_model` | model to use when the main one is overloaded | — | `--fallback-model` | `ZCO_FALLBACK_MODEL` | yes |
<!-- keys-table:end -->

### Keys only the user file may set

A project file is read automatically when you run a command inside the repository, including a
repository you just cloned. It can set what the repository could already set through its own
`.claude/` directory, which Claude Code loads without asking in `-p` mode: the system prompt
(like CLAUDE.md), tool rules, extra directories, the permission mode and an agent.

It cannot set the keys that would give a repository new ways to run programs of its choosing:

- `claude_cmd` would run an arbitrary program before Claude Code starts;
- `extra_args` could pass flags such as plugin directories;
- `mcp_config` would start MCP servers without the approval a project's `.mcp.json` needs;
- `settings` would lift repository settings into command-line scope;
- `permission_mode = bypassPermissions` would turn off permission checks;
- `models`, `prefix` and `raw_line` change your shell, not one run.

A project file that sets one of them stops the run with an error naming the key and the file.

### Showing the effective configuration

`--show-config` prints every setting for the invoked model, with its value and where it comes
from, and exits without running Claude Code. Other options on the same line are reflected:

```console
$ opus -n --show-config
# Effective configuration of opus (model opus).
# Each setting follows a comment naming where it comes from.
# user file:    ~/.zco.config
# project file: ~/proj/.zco.config
…
# command line
permission_mode = plan
# ~/.zco.config:7
effort = xhigh
# ~/proj/.zco.config:2
agent = reviewer
…
```

The output is itself a valid configuration file, so it can be pasted into one.

### Examples

A user file:

<!-- example-user-config:start -->
```ini
# ~/.zco.config
permission_mode = acceptEdits
effort = medium
append_system_prompt_file = ~/.config/zco/house-style.md

[opus]
effort = xhigh

[haiku]
max_budget_usd = 0.10
session_persistence = off
```
<!-- example-user-config:end -->

A project file, committed with the repository:

<!-- example-project-config:start -->
```ini
# ~/proj/.zco.config
agent = reviewer
add_dir = ../shared-lib
allowed_tools = Bash(git *)
allowed_tools = Edit
append_system_prompt_file = docs/assistant-style.md
```
<!-- example-project-config:end -->

## How Claude Code is run

Each run is one headless `claude -p` call in the current directory. A plain
`opus commit local changes`, with no configuration, runs:

```zsh
claude -p --model opus --permission-mode auto --strict-mcp-config -- 'commit local changes'
```

The model is passed exactly as named; Claude Code resolves aliases such as `opus` itself,
including `ANTHROPIC_DEFAULT_OPUS_MODEL` and friends. The prompt always comes last, after `--`,
as a single argument, so it is never mistaken for an option.

### The Claude Code command

The command is `claude` unless `ZCO_CLAUDE_CMD`, or `claude_cmd` in the user file, names
another. It may be a shell function, such as a wrapper that uses a second Claude Code
configuration, or several words:

```zsh
claude-work() { CLAUDE_CONFIG_DIR=~/.claude-work claude "$@" }
export ZCO_CLAUDE_CMD=claude-work

export ZCO_CLAUDE_CMD="env CLAUDE_CONFIG_DIR=$HOME/.claude-work claude"   # $HOME expands here, once
ZCO_CLAUDE_CMD=(env CLAUDE_CONFIG_DIR=$HOME/.claude-work claude)            # an array works too
```

A string is split into words the way zsh splits a command line, honouring quotes, but nothing
in it is expanded or evaluated. The command runs in the current shell, which is what makes
functions work; they run with zsh's default options. An alias cannot be used, because aliases
only expand where a line is typed: define a function instead. An alias named `claude` does not
affect the default command. If the command cannot be found, the run fails with status 127.

### Permission modes

The permission mode is `auto` unless the configuration says otherwise (`permission_mode`,
`ZCO_PERMISSION_MODE` or `--permission-mode`). In `-p` mode nobody can approve a tool call, so
any call your rules do not allow is denied without a question. With a mode that asks for
approval, a run would "succeed" having done nothing. `auto` lets Claude Code's classifier
approve routine actions and block risky ones.

If `auto` is not available for your account, provider or model, set another mode, for example
`permission_mode = acceptEdits` in `~/.zco.config`. The value is passed through unchanged, so
new Claude Code modes work without a plugin update. A project file cannot ask for
`bypassPermissions`.

### Dry run, then go ahead

`-n` runs in `plan` mode, whatever else is configured: Claude Code reads and plans but changes
nothing. Continue the same session to carry the plan out:

```zsh
haiku -n reorg this folder by year        # read the plan
haiku -c go ahead                         # the same session, now in the normal mode
```

`-c` continues the most recent Claude Code session in the current directory, which may be an
interactive session you had open there. To pick a session precisely, use `-r ID`
(`--resume ID`); the ID is required, because the interactive picker cannot work in `-p` mode.
`-c` and `-r` cannot be combined. Both need sessions to be saved, which is the default; set
`session_persistence = off` (or `ZCO_SESSION_PERSISTENCE=0`) to pass `--no-session-persistence`.

### Effort and haiku

`--effort` is passed only when you ask for one: an effort word, `-e`, `ZCO_EFFORT_<MODEL>`,
`ZCO_EFFORT` or `effort` in a configuration file. Otherwise Claude Code's own effort settings
apply. The header shows `settings` in that case.

Haiku models (any model whose name contains `haiku`) take no effort, so `--effort` is never
passed to them and the header shows `n/a`. When the effort came from a source meant for that
model, the command line, `ZCO_EFFORT_<MODEL>` or a `[haiku]` section, one notice says it was
dropped. An effort meant for every model, `ZCO_EFFORT` or an entry outside sections, is
dropped silently, so a global default does not make every haiku run print a notice.

### MCP servers

MCP servers are skipped by default with `--strict-mcp-config`. Together with reading stdin from
`/dev/null`, this brought a trivial haiku prompt from about 9 seconds to about 3 in our
measurements. `-m` (or `mcp = true`) loads the MCP servers Claude Code is
configured with. `--mcp-config FILE` (or `mcp_config` in the user file) loads only the servers in
that file; together with `-m`, it adds them to the configured ones.

### Budget and turns

`--max-budget-usd AMOUNT` (or `max_budget_usd`) stops the run when its cost would exceed the
amount, and `--max-turns N` (or `max_turns`) after N agentic turns.

### Options and the Claude Code arguments they become

| zsh-claude-oneshot | Claude Code | Key |
|---|---|---|
| effort word, `-e`, `--effort LEVEL` | `--effort LEVEL` (never for haiku) | `effort` |
| `-n`, `--dry-run` | `--permission-mode plan` | — |
| `--permission-mode MODE` | `--permission-mode MODE` | `permission_mode` |
| `-c`, `--continue` | `--continue` | — |
| `-r`, `--resume ID` | `--resume ID` | — |
| `-m`, `--mcp` | no `--strict-mcp-config` | `mcp` |
| `-a`, `--agent NAME` | `--agent NAME` | `agent` |
| `-s`, `--skill NAME` | the prompt starts with `/NAME` | — |
| `--system-prompt TEXT` | `--system-prompt TEXT` | `system_prompt` |
| `--system-prompt-file PATH` | `--system-prompt-file PATH` | `system_prompt_file` |
| `--append-system-prompt TEXT` | `--append-system-prompt TEXT` | `append_system_prompt` |
| `--append-system-prompt-file PATH` | `--append-system-prompt-file PATH` | `append_system_prompt_file` |
| `--add-dir DIR` | `--add-dir DIR`, once per directory | `add_dir` |
| `--allowed-tools RULE` | `--allowed-tools RULE`, once per rule | `allowed_tools` |
| `--disallowed-tools RULE` | `--disallowed-tools RULE`, once per rule | `disallowed_tools` |
| `--settings VALUE` | `--settings VALUE` | `settings` |
| `--mcp-config PATH` | `--mcp-config PATH`, once per file | `mcp_config` |
| `--fallback-model MODEL` | `--fallback-model MODEL` | `fallback_model` |
| `--max-turns N` | `--max-turns N` | `max_turns` |
| `--max-budget-usd AMOUNT` | `--max-budget-usd AMOUNT` | `max_budget_usd` |
| — | `--no-session-persistence` when false | `session_persistence` |

The arguments always come in this order:

```text
-p --model M --permission-mode MODE  --effort  --agent  --system-prompt[-file]
--append-system-prompt[-file]  --add-dir…  --allowed-tools…  --disallowed-tools…  --settings
--mcp-config…  --strict-mcp-config  --fallback-model  --max-turns  --continue | --resume ID
--no-session-persistence  --max-budget-usd  extra_args…  --output-format stream-json --verbose
-- PROMPT
```

### Skills: `-s` or `/skill`

`-s NAME` and typing `/NAME` at the start of the prompt send the same prompt. `-s` checks the
name (letters, digits and `: . _ -`, so plugin skills such as `my-plugin:review` work), accepts
a leading `/`, and counts as something to send, so `haiku -s prepare-commit` needs no prompt.

### System prompts: append rather than replace

`--system-prompt` replaces Claude Code's whole default system prompt, including its guidance on
using tools. For a house style or standing instructions, append instead:
`append_system_prompt` or `append_system_prompt_file`. Keep replacement for special cases. The
text and file forms of the same prompt count as one setting; giving both in one place is an
error, and a prompt file that cannot be read stops the run before Claude Code starts.

### Other Claude Code flags: `extra_args`

Any Claude Code flag without a dedicated option can be added in the user file, one argument per
line, and is passed after the options above:

```ini
extra_args = --name
extra_args = nightly-summary
```

An entry is refused when it is a flag zsh-claude-oneshot manages itself (such as `--model`,
`--effort` or `--continue`, plain or as `--flag=value`), a bundle of short options, or one of the
flags that are never passed.

### Flags that are never passed

`--bare`, `--safe-mode`, `--dangerously-skip-permissions` and
`--allow-dangerously-skip-permissions` are never passed, whatever the options, variables and
configuration files say, so your CLAUDE.md files, hooks and permission rules stay in force. A
test runs every combination of options, effort sources and settings to check this.

### Standard input and exit status

Input piped or redirected into the command (`git diff | haiku …`, `haiku … < notes.txt`) is
passed to Claude Code unchanged, together with the prompt if there is one. Otherwise Claude
Code reads from `/dev/null`, so it never waits for the terminal. The command returns Claude
Code's exit status, 2 for a usage or configuration error, and 127 when the Claude Code command
cannot be found.

## Output

The final answer goes to stdout; the header, progress and notices go to stderr.

## Typing prompts without quotes

A line that starts with a model command has its prompt quoted before zsh reads it.

## Completion

Tab completion covers options, effort words and option values.

## Security

- **Workspace trust.** `claude -p` skips Claude Code's workspace-trust dialog. Running a model
  command inside a directory therefore works like an interactive session in which you accepted
  the dialog: Claude Code loads the repository's CLAUDE.md and `.claude/` settings. Run
  commands in repositories you trust. The header names the directory every time.
- **Project files.** A `.zco.config` in the current directory or a parent is read
  automatically. It can only set what the repository could already set through its own
  `.claude/` directory; the keys that could run programs are refused (see
  [Keys only the user file may set](#keys-only-the-user-file-may-set)). When a project file
  applies, the header ends with `· local config`. `opus --show-config` shows what it sets, and
  `ZCO_LOCAL_CONFIG=0` ignores project files altogether.
- **No evaluation.** Configuration files and `ZCO_CLAUDE_CMD` are parsed as data. Nothing in
  them is expanded, substituted or executed.
- **Bypass flags.** The plugin never passes the flags that turn off permission checks, hooks or
  CLAUDE.md files; see [Flags that are never passed](#flags-that-are-never-passed).

## Related projects

- [shell_gpt](https://github.com/TheR1D/shell_gpt), [llm](https://github.com/simonw/llm),
  [aichat](https://github.com/sigoden/aichat) and [mods](https://github.com/charmbracelet/mods)
  are LLM clients for the terminal that work with many model providers.
- [zsh_codex](https://github.com/tom-doerr/zsh_codex) completes the command line with a model,
  from inside the zsh line editor.

What sets zsh-claude-oneshot apart: it does not talk to a model API itself. It runs Claude
Code, an agent that reads, edits and runs commands in the current directory under your own
CLAUDE.md, hooks and permission rules. The plugin's job is to make that one keystroke away,
with each model a command, prompts typed without quotes, and defaults kept in files.

## License

MIT. See [LICENSE](LICENSE).
