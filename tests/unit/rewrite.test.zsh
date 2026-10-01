# _zco_rewrite: the raw-line rewrite, line in, line out. The typed-line runs are in tests/rawline/.

zt_functions
typeset -gA _zco_cmds
_zco_cmds=( opus opus sonnet sonnet haiku haiku c-opus opus )

# Every case checked, for the idempotence property at the end.
typeset -ga ZT_CASES

assert_rewrite() {   # mode line expected
  ZT_CASES+=( "$1" "$2" )
  _zco_rewrite "$2" "$1"
  local rc=$?
  assert_eq "$REPLY" "$3" "rewrite ($1) of ${(qqqq)2}"
  if [[ $2 == "$3" ]]; then
    assert_eq $rc 1 "unchanged line must return 1: ${(qqqq)2}"
  else
    assert_eq $rc 0 "changed line must return 0: ${(qqqq)2}"
  fi
}

# The words zsh would run for a rewritten line (with alias and noglob semantics), in $reply.
zt_words_of() { reply=( "${(@Q)${(z)1}}" ) }

# ------------------------------------------------------------------ literal mode

# @scenario raw-line-capture: Apostrophe and redirection in the prompt
test_apostrophe_and_redirection() {
  assert_rewrite literal "opus xhigh don't touch tests > seriously" \
    "opus xhigh 'don'\\''t touch tests > seriously'"
  zt_words_of "$REPLY"
  assert_eq "${(j:|:)reply}" "opus|xhigh|don't touch tests > seriously"
}

# @scenario raw-line-capture: Command separators in the prompt
test_command_separators() {
  assert_rewrite literal 'sonnet edit README.md; then commit & push | done' \
    "sonnet 'edit README.md; then commit & push | done'"
}

# @scenario raw-line-capture: Expansion characters stay literal
test_expansion_characters_stay_literal() {
  local typed='opus explain $HOME, $(date), `id`, !!, # and ~/x'
  _zco_rewrite "$typed" literal
  zt_words_of "$REPLY"
  assert_eq "${reply[2]}" 'explain $HOME, $(date), `id`, !!, # and ~/x'
  assert_eq $#reply 2
}

# @scenario raw-line-capture: Multi-line prompt
test_multi_line_prompt() {
  assert_rewrite literal $'opus summarize:\n- item one' $'opus \'summarize:\n- item one\''
}

# @scenario raw-line-capture: Separator before an effort word
test_separator_before_an_effort_word() {
  assert_rewrite literal "opus -- high level overview, don't skip tests" \
    "opus -- 'high level overview, don'\\''t skip tests'"
}

# @scenario raw-line-capture: Quoted option value before an unquoted prompt
test_quoted_option_value_before_an_unquoted_prompt() {
  assert_rewrite literal "opus -a reviewer --system-prompt 'Be terse.' don't touch tests" \
    "opus -a reviewer --system-prompt 'Be terse.' 'don'\\''t touch tests'"
}

# @scenario raw-line-capture: Unknown option still reported
test_unknown_option_stays_unquoted() {
  assert_rewrite literal "opus -x don't commit" "opus -x 'don'\\''t commit'"
}

# @scenario raw-line-capture: Plain prompt kept as typed
test_plain_prompt_kept_as_typed() {
  assert_rewrite literal 'opus commit local changes' 'opus commit local changes'
  assert_rewrite literal 'opus fix bug #12' "opus 'fix bug #12'"
  assert_rewrite literal 'opus edit src/a.zsh, b.md: user@host 50% +1 -n' \
    'opus edit src/a.zsh, b.md: user@host 50% +1 -n'
}

# @scenario raw-line-capture: Re-running a rewritten line from history
test_rewritten_line_is_not_rewritten_again() {
  assert_rewrite literal "opus xhigh 'don'\\''t touch tests'" "opus xhigh 'don'\\''t touch tests'"
}

# @scenario raw-line-capture: User-quoted prompt
test_user_quoted_prompt() {
  assert_rewrite literal 'opus "fix the bug"' 'opus "fix the bug"'
  assert_rewrite literal "opus 'fix the bug'" "opus 'fix the bug'"
  assert_rewrite literal $'opus $\'it\\\'s\'' $'opus $\'it\\\'s\''
}

test_quotes_that_are_not_one_word_are_prompt_text() {
  assert_rewrite literal "opus 'tis the season, don't" "opus ''\\''tis the season, don'\\''t'"
  assert_rewrite literal 'opus "a" and "b"' "opus '\"a\" and \"b\"'"
}

# @scenario raw-line-capture: Pipeline into a model command
test_pipeline_into_a_model_command() {
  assert_rewrite literal 'git diff | haiku summarize for a changelog' 'git diff | haiku summarize for a changelog'
}

# @scenario raw-line-capture: Redirection through zco
test_redirection_through_zco() {
  assert_rewrite literal "zco opus 'write release notes' > notes.md" "zco opus 'write release notes' > notes.md"
}

test_other_lines_untouched() {
  local line
  for line in "{ opus don't } > out.md" "FOO=1 opus don't" "\\opus don't" "opusx don't" \
              "command opus don't" "echo opus don't" 'opus' '   ' '' "opus;ls don't"; do
    assert_rewrite literal "$line" "$line"
  done
}

test_leading_whitespace_tabs_and_trailing_spaces() {
  assert_rewrite literal $'  opus\tdon\'t  \t' $'  opus\t\'don\'\\\'\'t\''
}

test_options_and_effort_kept_as_typed() {
  assert_rewrite literal "opus  -n   high   don't" "opus  -n   high   'don'\\''t'"
  assert_rewrite literal "opus -e low --max-turns=3 don't" "opus -e low --max-turns=3 'don'\\''t'"
  assert_rewrite literal "opus --system-prompt='quoted value' don't" "opus --system-prompt='quoted value' 'don'\\''t'"
  assert_rewrite literal "opus -e low high don't" "opus -e low 'high don'\\''t'"
}

test_value_option_followed_by_an_unsafe_or_unterminated_value() {
  assert_rewrite literal "opus -a rev'iewer go" "opus '-a rev'\\''iewer go'"
  assert_rewrite literal 'opus -a ; ls' "opus '-a ; ls'"
  assert_rewrite literal 'opus --agent' 'opus --agent'
  assert_rewrite literal "opus --agent=it's x" "opus '--agent=it'\\''s x'"
}

test_shell_operators_right_after_the_options() {
  assert_rewrite literal 'opus -n | wc -l' "opus -n '| wc -l'"
  assert_rewrite literal 'opus -n > out' "opus -n '> out'"
  assert_rewrite literal 'opus -n;ls' "opus -n ';ls'"
}

test_ultracode_stays_detectable() {
  assert_rewrite literal "opus ultracode don't" "opus 'ultracode don'\\''t'"
}

test_prefixed_command_names() {
  assert_rewrite literal "c-opus don't" "c-opus 'don'\\''t'"
}

test_embedded_newlines_and_globs() {
  assert_rewrite literal $'opus a\nb' $'opus \'a\nb\''
  assert_rewrite literal 'opus which *.md files mention [install]?' "opus 'which *.md files mention [install]?'"
}

# ------------------------------------------------------------------ modes

# @scenario raw-line-capture: Literal by default
test_literal_by_default() {
  assert_rewrite literal 'opus write a commit message | pbcopy' "opus 'write a commit message | pbcopy'"
}

test_mode_off_leaves_lines_alone() {
  assert_rewrite off "opus don't touch" "opus don't touch"
  assert_rewrite off 'opus write | pbcopy' 'opus write | pbcopy'
}

# @scenario raw-line-capture: Literal flag while the default is off
test_literal_flag_while_off() {
  assert_rewrite off "opus --literal don't touch tests > seriously" \
    "opus --literal 'don'\\''t touch tests > seriously'"
}

# @scenario raw-line-capture: Last mode flag wins
test_last_mode_flag_wins() {
  assert_rewrite literal 'opus --shell --literal is a > b true' "opus --shell --literal 'is a > b true'"
  assert_rewrite literal "opus --literal --shell don't | wc" "opus --literal --shell 'don'\\''t' | wc"
}

test_mode_flag_inside_the_prompt_is_text() {
  assert_rewrite literal 'opus explain --shell | x' "opus 'explain --shell | x'"
  assert_rewrite shell "opus explain --literal don't | x" "opus 'explain --literal don'\\''t' | x"
}

# ------------------------------------------------------------------ shell mode

# @scenario raw-line-capture: Piping the answer
test_piping_the_answer() {
  assert_rewrite literal "opus --shell write a commit message, don't list tests | pbcopy" \
    "opus --shell 'write a commit message, don'\\''t list tests' | pbcopy"
}

# @scenario raw-line-capture: Shell mode as the default
test_shell_mode_as_the_default() {
  assert_rewrite shell 'opus write a commit message | pbcopy' 'opus write a commit message | pbcopy'
  assert_rewrite shell 'opus --literal is a > b true' "opus --literal 'is a > b true'"
}

# @scenario raw-line-capture: Attached operators stay prompt text
test_attached_operators_stay_prompt_text() {
  assert_rewrite literal 'opus --shell explain the <div> tag in README.md; be brief | less' \
    "opus --shell 'explain the <div> tag in README.md; be brief' | less"
  assert_rewrite shell "opus is a>b, don't" "opus 'is a>b, don'\\''t'"
}

# @scenario raw-line-capture: Operator inside a quoted phrase
test_operator_inside_a_quoted_phrase() {
  assert_rewrite literal "opus --shell count lines matching 'a | b' | wc -l" \
    "opus --shell 'count lines matching '\\''a | b'\\''' | wc -l"
  zt_words_of "${REPLY% | wc -l}"
  assert_eq "$reply[3]" "count lines matching 'a | b'"
}

# @scenario raw-line-capture: No operator on the line
test_no_operator_on_the_line() {
  assert_rewrite shell "opus --shell don't touch tests" "opus --shell 'don'\\''t touch tests'"
}

# @scenario raw-line-capture: Re-running a shell-mode line from history
test_rerunning_a_shell_mode_line() {
  assert_rewrite literal "opus --shell 'write a commit message' | pbcopy" "opus --shell 'write a commit message' | pbcopy"
  assert_rewrite shell "opus 'write a commit message, don'\\''t' | pbcopy" "opus 'write a commit message, don'\\''t' | pbcopy"
}

test_every_split_operator() {
  local op
  for op in '|' '|&' '||' '&&' ';' '&' '>' '>>' '>|' '&>' '&>>' '2>' '2>>' '2>&1' '<'; do
    assert_rewrite shell "opus don't $op next" "opus 'don'\\''t' $op next"
  done
}

test_operator_as_the_last_word_and_first_word() {
  assert_rewrite shell "opus don't |" "opus 'don'\\''t' |"
  assert_rewrite shell 'opus --shell | wc' 'opus --shell | wc'
  assert_rewrite shell "opus -n > out don't" "opus -n > out don't"
}

test_unclosed_quoted_phrase_runs_to_the_end() {
  assert_rewrite shell "opus say 'hello | wc" "opus 'say '\\''hello | wc'"
  assert_rewrite shell "opus say \"a b\" | wc" "opus 'say \"a b\"' | wc"
}

test_shell_mode_keeps_the_tail_verbatim() {
  assert_rewrite shell "opus don't  |   tr a-z A-Z   >  out.txt" "opus 'don'\\''t' |   tr a-z A-Z   >  out.txt"
  assert_rewrite shell $'opus line one\nline two, don\'t && ls' $'opus \'line one\nline two, don\'\\\'\'t\' && ls'
}

# ------------------------------------------------------------------ idempotence

test_rewriting_a_rewrite_changes_nothing() {
  # Run every case above once more to collect them, then check rewrite(rewrite(x)) == rewrite(x).
  local t
  for t in ${(k)functions[(I)test_*]}; do
    [[ $t == test_rewriting_a_rewrite_changes_nothing ]] && continue
    $t >/dev/null 2>&1
  done
  assert_ne $#ZT_CASES 0
  local mode line once mode2
  for mode line in "${ZT_CASES[@]}"; do
    for mode2 in $mode literal shell off; do
      _zco_rewrite "$line" $mode2
      once=$REPLY
      _zco_rewrite "$once" $mode2
      assert_eq "$REPLY" "$once" "not idempotent ($mode2): ${(qqqq)line}"
    done
  done
}

test_glued_quotes_with_expansions_are_prompt_text() {
  assert_rewrite literal "opus 'x'\$(touch pwned)'y'" "opus ''\\''x'\\''\$(touch pwned)'\\''y'\\'''"
  assert_rewrite literal 'opus "a"$(id)"b"' "opus '\"a\"\$(id)\"b\"'"
  assert_rewrite literal 'opus "a"`id`"b"' "opus '\"a\"\`id\`\"b\"'"
  assert_rewrite literal "opus \$'a'\$(id)\$'b'" "opus '\$'\\''a'\\''\$(id)\$'\\''b'\\'''"
  assert_rewrite literal 'opus "say \"hi\" now"' 'opus "say \"hi\" now"'
}
