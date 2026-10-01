# _zco_parse: effort, options, option values and the prompt.

zt_functions

assert_parsed() {   # key expected
  assert_eq "${P[$1]-<unset>}" "$2" "parsed $1"
}

assert_parse_error() {   # needle...: the parse failed and the message contains each needle
  assert_eq $ZT_RC 1 "parse should fail (message: ${(qqqq)REPLY})"
  local n
  for n in "$@"; do assert_contains "$REPLY" "$n"; done
}

# @scenario prompt-grammar: Prompt only
test_prompt_only() {
  zt_parse commit local changes
  assert_eq $ZT_RC 0
  assert_parsed effort '<unset>'
  assert_parsed prompt 'commit local changes'
}

# @scenario prompt-grammar: Effort word first
test_effort_word_first() {
  zt_parse xhigh commit local changes
  assert_parsed effort xhigh
  assert_parsed prompt 'commit local changes'
}

# @scenario prompt-grammar: Options and effort in either order
test_options_and_effort_in_either_order() {
  zt_parse -n high reorg this folder
  assert_parsed dry_run 1; assert_parsed effort high; assert_parsed prompt 'reorg this folder'
  zt_parse high -n reorg this folder
  assert_parsed dry_run 1; assert_parsed effort high; assert_parsed prompt 'reorg this folder'
}

# @scenario prompt-grammar: Options after the prompt start are prompt text
test_options_after_the_prompt_are_text() {
  zt_parse explain what -n does in grep
  assert_parsed dry_run '<unset>'
  assert_parsed prompt 'explain what -n does in grep'
}

# @scenario prompt-grammar: Effort word repeated as prompt text
test_effort_word_repeated() {
  zt_parse high high level overview
  assert_parsed effort high
  assert_parsed prompt 'high level overview'
}

# @scenario prompt-grammar: Capitalised word is prompt text
test_capitalised_word() {
  zt_parse High level overview
  assert_parsed effort '<unset>'
  assert_parsed prompt 'High level overview'
}

# @scenario prompt-grammar: Effort already set by option
test_effort_already_set_by_option() {
  zt_parse -e max high level overview
  assert_parsed effort max
  assert_parsed prompt 'high level overview'
}

test_effort_option_replaces_earlier_effort() {
  zt_parse low --effort high x
  assert_parsed effort high
  zt_parse --effort=low -e max x
  assert_parsed effort max
}

# @scenario prompt-grammar: Long form with equals
test_long_form_with_equals() {
  zt_parse --effort=low fix the typo
  assert_parsed effort low
  assert_parsed prompt 'fix the typo'
}

# @scenario prompt-grammar: Unknown level
test_unknown_level() {
  zt_parse -e extreme do it
  assert_parse_error extreme 'low medium high xhigh max'
}

test_missing_or_empty_level() {
  zt_parse -e
  assert_parse_error 'low medium high xhigh max'
  zt_parse --effort= x
  assert_parse_error 'low medium high xhigh max'
}

# @scenario prompt-grammar: Bare ultracode
test_bare_ultracode() {
  zt_parse ultracode refactor the parser
  assert_parse_error ultracode --
}

# @scenario prompt-grammar: ultracode after an effort word
test_ultracode_after_effort_word() {
  zt_parse high ultracode refactor the parser
  assert_parse_error ultracode
  zt_parse -n ultracode
  assert_parse_error ultracode
}

test_ultracode_as_effort_level() {
  zt_parse -e ultracode x
  assert_parse_error ultracode --
  zt_parse --effort=ultracode x
  assert_parse_error ultracode
}

test_ultracode_as_first_word_of_a_quoted_prompt() {
  zt_parse "ultracode refactor the parser"
  assert_parse_error ultracode
}

test_ultracode_later_in_the_prompt_is_fine() {
  zt_parse explain ultracode mode
  assert_eq $ZT_RC 0
  assert_parsed prompt 'explain ultracode mode'
}

# @scenario prompt-grammar: ultracode after the separator
test_ultracode_after_separator() {
  zt_parse -- ultracode refactor the parser
  assert_eq $ZT_RC 0
  assert_parsed prompt 'ultracode refactor the parser'
  assert_parsed effort '<unset>'
}

# @scenario prompt-grammar: Effort word as prompt text
test_separator_before_effort_word() {
  zt_parse -- high level overview of this repo
  assert_parsed effort '<unset>'
  assert_parsed prompt 'high level overview of this repo'
}

# @scenario prompt-grammar: Prompt starting with a dash
test_prompt_starting_with_a_dash() {
  zt_parse -- -v prints nothing, 'why?'
  assert_eq $ZT_RC 0
  assert_parsed prompt '-v prints nothing, why?'
  assert_parsed output '<unset>'
}

test_separator_alone_gives_no_prompt() {
  zt_parse -n --
  assert_eq $ZT_RC 0
  assert_parsed has_prompt '<unset>'
}

# @scenario prompt-grammar: Bundled options
test_bundled_options() {
  zt_parse -nc go ahead
  assert_parsed dry_run 1
  assert_parsed continue 1
  assert_parsed prompt 'go ahead'
}

test_every_flag_long_and_short() {
  zt_parse --dry-run --continue --mcp --show-config x
  assert_parsed dry_run 1; assert_parsed continue 1; assert_parsed mcp 1; assert_parsed show_config 1
  zt_parse -m -h
  assert_parsed mcp 1; assert_parsed help 1
  zt_parse --help
  assert_parsed help 1
}

# @scenario prompt-grammar: Verbose then quiet
test_verbose_then_quiet() {
  zt_parse -v -q commit
  assert_parsed output quiet
  zt_parse -q --verbose commit
  assert_parsed output verbose
  zt_parse -vq commit
  assert_parsed output quiet
}

# @scenario prompt-grammar: Line-mode options at run time
test_line_mode_options_are_accepted() {
  zt_parse --shell summarize the diff
  assert_eq $ZT_RC 0
  assert_parsed prompt 'summarize the diff'
  assert_parsed line_mode shell
  zt_parse --shell --literal x
  assert_parsed line_mode literal
}

# @scenario prompt-grammar: Value in the next argument
test_value_in_next_argument() {
  zt_parse --agent reviewer high check this
  assert_parsed agent reviewer
  assert_parsed effort high
  assert_parsed prompt 'check this'
}

test_values_are_taken_as_given() {
  zt_parse -a high -s -dash --system-prompt -- x
  assert_parsed agent high
  assert_parsed skill -dash
  assert_parsed system_prompt --
  assert_parsed prompt x
  assert_parsed effort '<unset>'
}

# @scenario prompt-grammar: Value with equals
test_value_with_equals() {
  zt_parse '--system-prompt=Be terse.' summarize
  assert_parsed system_prompt 'Be terse.'
  assert_parsed prompt summarize
  zt_parse --agent=a=b x
  assert_parsed agent a=b
}

# @scenario prompt-grammar: Missing value
test_missing_value() {
  zt_parse --agent
  assert_parse_error --agent
  zt_parse x --agent
  assert_eq $ZT_RC 0 "after the prompt starts, --agent is text"
}

test_empty_values_are_errors() {
  zt_parse --agent= x
  assert_parse_error --agent
  zt_parse --agent '' x
  assert_parse_error --agent
}

test_every_value_option_lands_in_its_key() {
  zt_parse -r ID1 --permission-mode acceptEdits --system-prompt-file p.md \
    --append-system-prompt T --append-system-prompt-file a.md --settings s.json \
    --fallback-model sonnet --max-turns 5 --max-budget-usd 0.5 -s rev x
  assert_eq $ZT_RC 0
  assert_parsed resume ID1
  assert_parsed permission_mode acceptEdits
  assert_parsed system_prompt_file p.md
  assert_parsed append_system_prompt T
  assert_parsed append_system_prompt_file a.md
  assert_parsed settings s.json
  assert_parsed fallback_model sonnet
  assert_parsed max_turns 5
  assert_parsed max_budget_usd 0.5
  assert_parsed skill rev
}

test_repeated_list_options_accumulate() {
  zt_parse --add-dir a --add-dir 'b c' --allowed-tools 'Bash(git *)' --allowed-tools=Edit \
    --disallowed-tools Write --mcp-config one.json --mcp-config=two.json x
  assert_eq $ZT_RC 0
  zt_list "$P[add_dir]"; assert_eq "${(j:|:)reply}" 'a|b c'
  zt_list "$P[allowed_tools]"; assert_eq "${(j:|:)reply}" 'Bash(git *)|Edit'
  zt_list "$P[disallowed_tools]"; assert_eq "${(j:|:)reply}" Write
  zt_list "$P[mcp_config]"; assert_eq "${(j:|:)reply}" 'one.json|two.json'
}

# @scenario prompt-grammar: Typo in an option
test_typo_in_an_option() {
  zt_parse -x commit
  assert_parse_error -x --
}

test_bundle_with_a_value_option_is_unknown() {
  zt_parse -ne high x
  assert_parse_error -ne --
}

test_bare_dash_is_prompt_text() {
  zt_parse - is a dash
  assert_eq $ZT_RC 0
  assert_parsed prompt '- is a dash'
}

test_resume_and_continue_together() {
  zt_parse -c -r abc go ahead
  assert_parse_error -c -r
}

test_prompt_words_are_joined_with_single_spaces() {
  zt_parse 'a  b' c '' d
  assert_parsed prompt 'a  b c  d'
  assert_parsed has_prompt 1
}

test_effort_level_is_not_a_pattern() {
  zt_parse -e '*' x
  assert_parse_error "'*'"
  zt_parse --effort='h*' x
  assert_parse_error "'h*'"
}
