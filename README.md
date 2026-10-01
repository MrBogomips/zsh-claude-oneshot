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

Defaults that repeat across runs can live in `~/.zco.config` and in a project's `.zco.config`.

## How Claude Code is run

Each run is a headless `claude -p` call in the current directory.

## Output

The final answer goes to stdout; the header, progress and notices go to stderr.

## Typing prompts without quotes

A line that starts with a model command has its prompt quoted before zsh reads it.

## Completion

Tab completion covers options, effort words and option values.

## Security

`claude -p` skips Claude Code's workspace-trust dialog.

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
