# raw-line-capture: lines typed into a real interactive zsh (under zpty), down to the arguments
# Claude Code receives, what a pipe or file receives, and no stray files.

source $ZT_TESTS/lib/pty.zsh

# Start zsh -i with the plugin. Lines given before -- go before loading it, lines after it after.
zt_rl_start() {
  local -a before after
  while (( $# )) && [[ $1 != -- ]]; do before+=( "$1" ); shift; done
  [[ $1 == -- ]] && shift
  after=( "$@" )
  zt_pty_start 'bindkey -e' \
    "pbcopy() { cat > ${(q)ZT_TMP}/clipboard }" \
    "less() { cat > ${(q)ZT_TMP}/paged }" \
    "git() { print -r -- 'diff --git a/x b/x' }" \
    "${before[@]}" "source ${(q)ZT_PLUGIN}" "${after[@]}"
}

# Entries of the current directory, to show that no file appeared.
zt_snapshot() { local -a e; e=( *(DN) ); REPLY=${(j: :)${(o)e}} }

assert_prompt() {   # expected prompt of the last Claude Code call
  zt_claude_argv || zt_fail "Claude Code was not run" "  terminal: ${(qqqq)ZT_PTY_OUT}"
  assert_eq "${reply[-1]}" "$1" "prompt received by Claude Code"
  assert_eq "${reply[-2]}" -- "the prompt follows --"
}

zt_last_history() {   # the last history entry before this one, in REPLY
  zt_pty_run 'fc -ln -1'
  REPLY=${ZT_PTY_OUT%$'\n'}
}

# ------------------------------------------------------------------ literal mode

# @scenario raw-line-capture: Apostrophe and redirection in the prompt
test_apostrophe_and_redirection_typed() {
  zt_snapshot; local before=$REPLY
  zt_rl_start
  zt_pty_run "opus xhigh don't touch tests > seriously"
  zt_pty_stop
  assert_prompt "don't touch tests > seriously"
  assert_argv_has --effort xhigh
  assert_file_absent seriously
  zt_snapshot; assert_eq "$REPLY" "$before" "no stray files"
}

# @scenario raw-line-capture: Command separators in the prompt
test_command_separators_typed() {
  zt_snapshot; local before=$REPLY
  zt_rl_start
  zt_pty_run 'sonnet edit README.md; then commit & push | done'
  zt_pty_stop
  assert_prompt 'edit README.md; then commit & push | done'
  assert_eq "$(zt_claude_calls)" 1 "no other command runs"
  assert_not_contains "$ZT_PTY_OUT" 'command not found'
  zt_snapshot; assert_eq "$REPLY" "$before"
}

# @scenario raw-line-capture: Expansion characters stay literal
test_expansion_characters_typed() {
  zt_rl_start
  zt_pty_run 'opus explain $HOME, $(date), `id`, !!, # and ~/x'
  zt_pty_stop
  assert_prompt 'explain $HOME, $(date), `id`, !!, # and ~/x'
}

# @scenario raw-line-capture: Multi-line prompt
test_multi_line_prompt_typed() {
  zt_rl_start
  zt_pty_send 'opus summarize:'
  zt_pty_send $'\e\r'            # ESC Enter inserts a newline into the edit buffer
  zt_pty_run '- item one'
  zt_pty_stop
  assert_prompt $'summarize:\n- item one'
}

# @scenario raw-line-capture: Separator before an effort word
test_separator_before_an_effort_word_typed() {
  zt_rl_start
  zt_pty_run "opus -- high level overview, don't skip tests"
  zt_pty_stop
  assert_prompt "high level overview, don't skip tests"
  assert_argv_lacks --effort
}

# @scenario raw-line-capture: Quoted option value before an unquoted prompt
test_quoted_option_value_typed() {
  zt_rl_start
  zt_pty_run "opus -a reviewer --system-prompt 'Be terse.' don't touch tests"
  zt_pty_stop
  assert_prompt "don't touch tests"
  assert_argv_has --agent reviewer --system-prompt 'Be terse.'
}

# @scenario raw-line-capture: Unknown option still reported
test_unknown_option_still_reported_typed() {
  zt_rl_start
  zt_pty_run "opus -x don't commit"
  zt_pty_stop
  assert_contains "$ZT_PTY_OUT" "unknown option '-x'"
  assert_not_run
}

# @scenario raw-line-capture: Plain prompt kept as typed
test_plain_prompt_kept_as_typed_typed() {
  zt_rl_start
  zt_pty_run 'opus commit local changes'
  zt_last_history
  zt_pty_stop
  assert_eq "$REPLY" 'opus commit local changes'
  assert_prompt 'commit local changes'
}

# @scenario raw-line-capture: Re-running a rewritten line from history
test_rerunning_a_rewritten_line_typed() {
  zt_rl_start
  zt_pty_run "opus xhigh don't touch tests"
  zt_pty_keys $'\x10\r'          # Ctrl-P recalls the previous line, Enter runs it
  zt_pty_run 'fc -ln -2'
  zt_pty_stop
  assert_eq "$(zt_claude_calls)" 2
  assert_prompt "don't touch tests"
  local -a hist=( "${(@f)${ZT_PTY_OUT%$'\n'}}" )
  assert_eq "$hist[1]" "opus xhigh 'don'\\''t touch tests'"
  assert_eq "$hist[2]" "$hist[1]" "the recalled line is not changed again"
}

# @scenario raw-line-capture: User-quoted prompt
test_user_quoted_prompt_typed() {
  zt_rl_start
  zt_pty_run 'opus "fix the bug"'
  zt_pty_stop
  assert_prompt 'fix the bug'
}

# @scenario raw-line-capture: Pipeline into a model command
test_pipeline_into_a_model_command_typed() {
  zt_rl_start
  zt_pty_run 'git diff | haiku summarize for a changelog'
  zt_last_history
  zt_pty_stop
  assert_eq "$REPLY" 'git diff | haiku summarize for a changelog'
  assert_prompt 'summarize for a changelog'
  zt_claude_stdin; assert_eq "$REPLY" $'diff --git a/x b/x\n'
}

# @scenario raw-line-capture: Redirection through zco
test_redirection_through_zco_typed() {
  export FAKE_CLAUDE_ANSWER='release notes'
  zt_rl_start
  zt_pty_run "zco opus 'write release notes' > notes.md"
  zt_pty_stop
  assert_eq "$(<notes.md)" 'release notes'
  assert_prompt 'write release notes'
}

# @scenario raw-line-capture: Continuation line
test_continuation_line_typed() {
  zt_rl_start
  zt_pty_keys 'print -r -- "multi'$'\r' '<ZT-CONT>'
  zt_pty_run "opus don't\""
  zt_pty_stop
  assert_contains "$ZT_PTY_OUT" $'multi\nopus don\'t'
  assert_not_run
}

# @scenario raw-line-capture: History holds the quoted form
test_history_holds_the_quoted_form() {
  zt_rl_start
  zt_pty_run "opus don't touch tests"
  zt_last_history
  local entry=$REPLY
  zt_pty_run 'r opus'          # re-run the last line that starts with opus
  zt_pty_stop
  assert_eq "$entry" "opus 'don'\\''t touch tests'"
  assert_eq "$(zt_claude_calls)" 2
  assert_prompt "don't touch tests"
}

# @scenario model-commands: Glob characters with raw-line capture off
test_glob_characters_with_capture_off_typed() {
  touch a.md
  zt_rl_start 'ZCO_RAW_LINE=0'
  zt_pty_run 'opus which *.md files mention [install]?'
  zt_pty_stop
  assert_not_contains "$ZT_PTY_OUT" 'no matches found'
  assert_prompt 'which *.md files mention [install]?'
}

# ------------------------------------------------------------------ line modes

# @scenario raw-line-capture: Literal by default
test_literal_by_default_typed() {
  zt_rl_start
  zt_pty_run 'opus write a commit message | pbcopy'
  zt_pty_stop
  assert_prompt 'write a commit message | pbcopy'
  assert_file_absent $ZT_TMP/clipboard "nothing is piped"
}

# @scenario raw-line-capture: Turned off in a live shell
test_turned_off_in_a_live_shell() {
  zt_rl_start
  zt_pty_run 'ZCO_RAW_LINE=0'
  zt_pty_keys "opus don't"$'\r' '<ZT-CONT>'     # zsh waits for the closing quote
  zt_pty_keys $'\x03'                           # Ctrl-C back to the prompt
  zt_pty_stop
  assert_not_run
}

# @scenario raw-line-capture: Literal flag while the default is off
test_literal_flag_while_the_default_is_off() {
  zt_user_config 'raw_line = off'
  zt_rl_start
  zt_pty_run "opus --literal don't touch tests > seriously"
  zt_pty_stop
  assert_prompt "don't touch tests > seriously"
  assert_file_absent seriously
}

# @scenario raw-line-capture: Shell mode as the default
test_shell_mode_as_the_default_typed() {
  export FAKE_CLAUDE_ANSWER='feat: a commit message'
  zt_rl_start 'export ZCO_RAW_LINE=shell'
  zt_pty_run 'opus write a commit message | pbcopy'
  assert_eq "$(<$ZT_TMP/clipboard)" 'feat: a commit message' "the answer is piped"
  zt_pty_run 'opus --literal is a > b true'
  zt_pty_stop
  assert_prompt 'is a > b true'
  assert_file_absent b
}

# @scenario raw-line-capture: Last mode flag wins
test_last_mode_flag_wins_typed() {
  zt_rl_start
  zt_pty_run 'opus --shell --literal is a > b true'
  zt_pty_stop
  assert_prompt 'is a > b true'
  assert_file_absent b
}

# @scenario raw-line-capture: No per-model commands
test_no_per_model_commands() {
  zt_rl_start 'ZCO_MODELS=()'
  zt_pty_run 'print -r -- "hook=${+widgets[_zco_line_finish]} preexec=${(j:,:)preexec_functions}"'
  zt_pty_stop
  assert_contains "$ZT_PTY_OUT" 'hook=0 preexec='
  assert_not_contains "$ZT_PTY_OUT" _zco_preexec
}

# @scenario model-commands: Sourced twice
test_sourced_twice_registers_one_hook() {
  zt_rl_start -- "source ${(q)ZT_PLUGIN}"
  zt_pty_run 'zstyle -g w zle-line-finish widgets; print -r -- "hooks=${(M)#w:#*_zco_line_finish} preexec=${(M)#preexec_functions:#_zco_preexec}"'
  zt_pty_stop
  assert_contains "$ZT_PTY_OUT" 'hooks=1 preexec=1'
  assert_not_contains "$ZT_PTY_OUT" 'zsh-claude-oneshot:'
}

# ------------------------------------------------------------------ shell mode

# @scenario raw-line-capture: Piping the answer
test_piping_the_answer_typed() {
  export FAKE_CLAUDE_ANSWER='feat: tidy'
  zt_rl_start
  zt_pty_run "opus --shell write a commit message, don't list tests | pbcopy"
  zt_last_history
  zt_pty_stop
  assert_eq "$REPLY" "opus --shell 'write a commit message, don'\\''t list tests' | pbcopy"
  assert_prompt "write a commit message, don't list tests"
  assert_eq "$(<$ZT_TMP/clipboard)" 'feat: tidy'
}

# @scenario run-output: Answer piped to another command
test_answer_piped_to_another_command() {
  (( $+commands[jq] )) || zt_skip "jq is not installed"
  zt_mkdir_cd ~/proj
  zt_stream_here stream-tools.jsonl
  export FAKE_CLAUDE_STREAM=$REPLY
  zt_rl_start
  zt_pty_run 'opus --shell write a commit message for the staged changes | pbcopy'
  zt_pty_stop
  zt_raw $ZT_TMP/clipboard
  assert_eq "$REPLY" $'Committed 3 files.\n' "only the answer reaches pbcopy"
  assert_contains "$ZT_PTY_OUT" 'opus · settings · auto · ~/proj'
  assert_contains "$ZT_PTY_OUT" '→ Bash  git diff --stat'
}

# @scenario raw-line-capture: Redirecting the answer
test_redirecting_the_answer_typed() {
  export FAKE_CLAUDE_ANSWER='a summary'
  zt_rl_start
  zt_pty_run 'opus --shell summarize this repo > notes.md'
  zt_pty_stop
  assert_eq "$(<notes.md)" 'a summary'
  assert_prompt 'summarize this repo'
}

# @scenario raw-line-capture: Chaining a command
test_chaining_a_command() {
  touch marker-file
  zt_rl_start
  zt_pty_run 'haiku -n --shell reorg this folder by year && ls'
  zt_pty_stop
  assert_prompt 'reorg this folder by year'
  assert_contains "$ZT_PTY_OUT" marker-file "ls runs after haiku succeeds"
}

test_chaining_stops_when_claude_fails() {
  touch marker-file
  export FAKE_CLAUDE_EXIT=1
  zt_rl_start
  zt_pty_run "haiku --shell don't && ls"
  zt_pty_stop
  assert_not_contains "$ZT_PTY_OUT" marker-file
}

# @scenario raw-line-capture: Attached operators stay prompt text
test_attached_operators_typed() {
  export FAKE_CLAUDE_ANSWER='paged answer'
  zt_rl_start
  zt_pty_run 'opus --shell explain the <div> tag in README.md; be brief | less'
  zt_pty_stop
  assert_prompt 'explain the <div> tag in README.md; be brief'
  assert_eq "$(<$ZT_TMP/paged)" 'paged answer'
}

# @scenario raw-line-capture: Operator inside a quoted phrase
test_operator_inside_a_quoted_phrase_typed() {
  export FAKE_CLAUDE_ANSWER=$'one\ntwo\nthree'
  zt_rl_start
  zt_pty_run "opus --shell count lines matching 'a | b' | wc -l"
  zt_pty_stop
  assert_prompt "count lines matching 'a | b'"
  assert_match "$ZT_PTY_OUT" "*[[:space:]]3[[:space:]]*"
}

# @scenario raw-line-capture: No operator on the line
test_no_operator_on_the_line_typed() {
  zt_rl_start
  zt_pty_run "opus --shell don't touch tests"
  zt_pty_stop
  assert_prompt "don't touch tests"
}

# @scenario raw-line-capture: Re-running a shell-mode line from history
test_rerunning_a_shell_mode_line_typed() {
  export FAKE_CLAUDE_ANSWER='again'
  zt_rl_start
  zt_pty_run "opus --shell 'write a commit message' | pbcopy"
  rm -f $ZT_TMP/clipboard
  zt_pty_keys $'\x10\r'
  zt_last_history
  zt_pty_stop
  assert_eq "$REPLY" "opus --shell 'write a commit message' | pbcopy"
  assert_eq "$(<$ZT_TMP/clipboard)" again
  assert_eq "$(zt_claude_calls)" 2
}
