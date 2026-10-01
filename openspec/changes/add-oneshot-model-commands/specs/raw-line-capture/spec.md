# Spec Delta

<!-- Revision 1.3.0 (2026-10-01): shell mode does not split at an operator that zsh itself reads as quoted text (from the security review). -->

## Purpose

Lets users type prompts unquoted on the interactive command line. The prompt part of a line that starts with a model command is quoted before zsh parses it, so apostrophes and shell metacharacters stay part of the prompt. A per-line flag lets the shell take over after the prompt, for pipes and redirections.

## ADDED Requirements

### Requirement: Rewrite of model-command lines
When an interactive command line is accepted and its first word is exactly one of the plugin's per-model command names, the prompt part SHALL be turned into a single shell-quoted word before zsh parses the line. In literal mode, the default, the prompt part is the whole rest of the line; shell mode ends it earlier (see "Shell mode"). The leading whitespace, the command name, and the effort word, options and `--` before the prompt SHALL stay as typed. Claude Code SHALL receive the prompt text exactly as typed, apart from leading and trailing whitespace.

#### Scenario: Apostrophe and redirection in the prompt
- **WHEN** the user types `opus xhigh don't touch tests > seriously` and presses Enter
- **THEN** Claude Code runs with effort `xhigh` and the prompt `don't touch tests > seriously`, zsh does not wait for a closing quote and no file named `seriously` is created

#### Scenario: Command separators in the prompt
- **WHEN** the user types `sonnet edit README.md; then commit & push | done` and presses Enter
- **THEN** Claude Code receives the prompt `edit README.md; then commit & push | done` and no other command runs

#### Scenario: Expansion characters stay literal
- **WHEN** the user types ``opus explain $HOME, $(date), `id`, !!, # and ~/x`` and presses Enter
- **THEN** Claude Code receives exactly that text after `opus `, with no expansion performed

#### Scenario: Multi-line prompt
- **WHEN** the edit buffer holds `opus summarize:` followed by a newline and `- item one`
- **THEN** Claude Code receives the prompt with the newline kept

### Requirement: Same split as the grammar
The rewrite SHALL find where the prompt starts with the same rules the command uses to parse its arguments. Arguments before the prompt that start with `-` SHALL be left unquoted, so an unknown option still gives a usage error. So SHALL option values, including values the user quoted, such as `--system-prompt 'Be terse.'`. They keep their normal zsh meaning.

#### Scenario: Separator before an effort word
- **WHEN** the user types `opus -- high level overview, don't skip tests` and presses Enter
- **THEN** no effort is set and the prompt is `high level overview, don't skip tests`

#### Scenario: Quoted option value before an unquoted prompt
- **WHEN** the user types `opus -a reviewer --system-prompt 'Be terse.' don't touch tests` and presses Enter
- **THEN** Claude Code receives agent `reviewer`, the system prompt `Be terse.` and the prompt `don't touch tests`

#### Scenario: Unknown option still reported
- **WHEN** the user types `opus -x don't commit` and presses Enter
- **THEN** a usage error naming `-x` is printed and Claude Code is not run

### Requirement: Rewrite only when needed
The line SHALL be left unchanged when its prompt part contains only letters, digits, spaces, tabs and the characters `, . _ : / @ % + -`. In shell mode, the prompt part is the text before the end of the prompt.

#### Scenario: Plain prompt kept as typed
- **WHEN** the user types `opus commit local changes` and presses Enter
- **THEN** the line that runs and is saved in history is `opus commit local changes`

### Requirement: Idempotent rewrite
A prompt part that is already exactly one quoted shell word SHALL be left unchanged. It then keeps its normal zsh meaning. Applying the rewrite to its own output SHALL return the same line.

#### Scenario: Re-running a rewritten line from history
- **WHEN** the user recalls the rewritten line of `opus xhigh don't touch tests` from history and presses Enter
- **THEN** the line is not changed again and Claude Code receives the prompt `don't touch tests`

#### Scenario: User-quoted prompt
- **WHEN** the user types `opus "fix the bug"` and presses Enter
- **THEN** Claude Code receives the prompt `fix the bug`, without quote characters

### Requirement: Other lines untouched
The rewrite SHALL NOT change any of these:
- Lines whose first word is not a per-model command name. This includes `git diff | haiku summarize`, `zco opus '…' > out.md`, `{ opus '…' } > out.md`, `FOO=1 opus …` and `\opus …`.
- Continuation lines.
- Input read with `vared`.

#### Scenario: Pipeline into a model command
- **WHEN** the user types `git diff | haiku summarize for a changelog` and presses Enter
- **THEN** the line runs unchanged and haiku receives the diff on stdin

#### Scenario: Redirection through zco
- **WHEN** the user types `zco opus 'write release notes' > notes.md` and presses Enter
- **THEN** the line runs unchanged and the answer is written to `notes.md`

#### Scenario: Continuation line
- **WHEN** a line typed at a continuation prompt starts with `opus`
- **THEN** that line is not rewritten

### Requirement: Rewritten line is what runs and is recorded
The line zsh executes, shows on accept and saves in history SHALL be the rewritten line.

#### Scenario: History holds the quoted form
- **WHEN** the user runs `opus don't touch tests` and then lists the last history entry
- **THEN** the entry is the rewritten line, and running it gives the same prompt

### Requirement: Line modes
Each line starting with a per-model command SHALL be handled in one of three modes:
- `literal`: the whole rest of the line after the options is prompt text, as described above.
- `shell`: the prompt ends at the first shell operator written as a separate word, and zsh parses the rest of the line normally (see "Shell mode").
- `off`: the line is not rewritten.

The mode SHALL come from the last `--literal` or `--shell` given before the prompt on that line. Otherwise it comes from the `raw_line` setting (`ZCO_RAW_LINE`, or `raw_line` in the user file), which takes these values:
- `literal`, the default. `on`, `1`, `true` and `yes` mean the same.
- `shell`.
- `off`. `0`, `false` and `no` mean the same.

`ZCO_RAW_LINE` SHALL be read for every accepted line. An invalid value SHALL produce one warning on stderr when the plugin loads, and `literal` SHALL then apply. The rewrite hook SHALL be installed whenever at least one per-model command is defined, so that the flags work with every default.

#### Scenario: Literal by default
- **WHEN** no `raw_line` setting is given and the user types `opus write a commit message | pbcopy` and presses Enter
- **THEN** Claude Code receives the prompt `write a commit message | pbcopy` and nothing is piped

#### Scenario: Turned off in a live shell
- **WHEN** the plugin was loaded with the default mode and the user runs `ZCO_RAW_LINE=0`, then types `opus don't`
- **THEN** the line is not rewritten and zsh waits for the closing quote as usual

#### Scenario: Literal flag while the default is off
- **WHEN** the user file contains `raw_line = off` and the user types `opus --literal don't touch tests > seriously` and presses Enter
- **THEN** Claude Code receives the prompt `don't touch tests > seriously` and no file named `seriously` is created

#### Scenario: Shell mode as the default
- **WHEN** `ZCO_RAW_LINE=shell` is set and the user types `opus write a commit message | pbcopy`, then `opus --literal is a > b true` and presses Enter after each
- **THEN** the first answer is piped to `pbcopy`, and the second run receives the prompt `is a > b true`

#### Scenario: Last mode flag wins
- **WHEN** the user types `opus --shell --literal is a > b true` and presses Enter
- **THEN** Claude Code receives the prompt `is a > b true`

#### Scenario: No per-model commands
- **WHEN** the plugin is loaded with `ZCO_MODELS=()`
- **THEN** no line-rewrite hook is registered

### Requirement: Shell mode
In shell mode, the prompt SHALL end at the first word that meets all of these conditions:
- It is outside a phrase the user quoted.
- It is exactly one of `|` `|&` `||` `&&` `;` `&` `>` `>>` `>|` `&>` `&>>` `2>` `2>>` `2>&1` `<`.
- It is preceded by whitespace and followed by whitespace or the end of the line.
- When zsh can read the whole prompt part without a quote left open, zsh also reads the word as an operator, not as quoted text.

A quoted phrase starts at a word beginning with `'` or `"` and ends at the next word ending with the same character. The text before the end of the prompt is the prompt part, and it is treated as in literal mode: quoted when needed, and left alone when it is already one quoted word. The operator and everything after it SHALL be left unchanged for zsh. Operators attached to other text SHALL stay prompt text. A line without such an operator SHALL be handled as in literal mode.

#### Scenario: Piping the answer
- **WHEN** the user types `opus --shell write a commit message, don't list tests | pbcopy` and presses Enter
- **THEN** the line becomes `opus --shell 'write a commit message, don'\''t list tests' | pbcopy`, Claude Code receives the prompt `write a commit message, don't list tests`, and `pbcopy` receives the answer

#### Scenario: Redirecting the answer
- **WHEN** the user types `opus --shell summarize this repo > notes.md` and presses Enter
- **THEN** `notes.md` contains the answer

#### Scenario: Chaining a command
- **WHEN** the user types `haiku -n --shell reorg this folder by year && ls` and presses Enter
- **THEN** `ls` runs after haiku exits successfully

#### Scenario: Attached operators stay prompt text
- **WHEN** the user types `opus --shell explain the <div> tag in README.md; be brief | less` and presses Enter
- **THEN** Claude Code receives the prompt `explain the <div> tag in README.md; be brief` and the answer is shown by `less`

#### Scenario: Operator inside a quoted phrase
- **WHEN** the user types `opus --shell count lines matching 'a | b' | wc -l` and presses Enter
- **THEN** Claude Code receives the prompt `count lines matching 'a | b'`, quote characters included, and `wc -l` receives the answer

#### Scenario: Operator quoted for zsh
- **WHEN** the user types `opus --shell x'y | touch out \'` and presses Enter
- **THEN** the line is handled as in literal mode: Claude Code receives the prompt `x'y | touch out \'` and no file named `out` is created

#### Scenario: No operator on the line
- **WHEN** the user types `opus --shell don't touch tests` and presses Enter
- **THEN** the line is handled as in literal mode and Claude Code receives the prompt `don't touch tests`

#### Scenario: Re-running a shell-mode line from history
- **WHEN** the user recalls `opus --shell 'write a commit message' | pbcopy` from history and presses Enter
- **THEN** the line is not changed and the answer is piped to `pbcopy`

### Requirement: Coexistence with other line-editor plugins
Raw-line capture SHALL work together with each of the following, whichever loads first:
- zsh-syntax-highlighting.
- zsh-autosuggestions.
- A `zle-line-finish` widget defined before the plugin loads, as oh-my-zsh does.

Those widgets SHALL keep working. If another plugin later replaces the `zle-line-finish` widget, raw-line capture SHALL detect it when the next command line runs without the rewrite hook. It SHALL then be restored from the following prompt on, without disabling the replacing widget.

#### Scenario: Loaded after an existing zle-line-finish widget
- **WHEN** a `zle-line-finish` widget exists before the plugin loads and the user types `opus don't touch tests`
- **THEN** the existing widget still runs on every accepted line and the prompt reaches Claude Code intact

#### Scenario: Loaded before and after zsh-syntax-highlighting
- **WHEN** zsh-syntax-highlighting and zsh-autosuggestions are loaded before, or after, the plugin
- **THEN** in both orders, `opus don't touch tests > seriously` reaches Claude Code intact and highlighting and suggestions keep working

#### Scenario: Widget replaced later
- **WHEN** after loading, another plugin defines a new `zle-line-finish` widget directly and the user runs one command line
- **THEN** from the following prompt on, both that widget and the line rewrite run on every accepted line
