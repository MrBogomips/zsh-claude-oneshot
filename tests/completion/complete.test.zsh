# shell-completion: what Tab offers for the per-model commands and zco, in an interactive zsh.

source $ZT_TESTS/lib/pty.zsh

# Start zsh -i with completion; `late` runs compinit after loading the plugin.
zt_comp_start() {   # [late] [zshrc line...]
  local order=early
  [[ $1 == late ]] && { order=late; shift }
  export ZT_COMP_FILE=$ZT_TMP/completions
  local compinit="autoload -Uz compinit && compinit -u -d ${(q)ZT_TMP}/zcompdump"
  local capture="source ${(q)ZT_TESTS}/lib/capture-completion.zsh"
  if [[ $order == early ]]; then
    zt_pty_start 'bindkey -e' "$@" "$compinit" "$capture" "source ${(q)ZT_PLUGIN}"
  else
    zt_pty_start 'bindkey -e' "$@" "source ${(q)ZT_PLUGIN}" "$compinit" "$capture"
  fi
}

# Type TEXT, press Tab, and collect the offered matches in $reply ("match<TAB>description").
# Completion adds nothing while more input is pending, so each key goes alone: the text once zle
# has drawn the prompt, Tab once the text is drawn, and the done key once matches appeared (or
# after two seconds, for completions that offer nothing).
zt_complete() {   # text
  rm -f -- $ZT_COMP_FILE $ZT_COMP_FILE.done
  zt_pty_wait 5 '<ZT-PROMPT>' || zt_fail "no prompt drawn"
  zt_pty_send "$1"
  zt_pty_wait 5 "${1[-3,-1]}" || zt_fail "the text ${(qqqq)1} was not drawn"
  zt_pty_send $'\t'
  local -F deadline=$(( EPOCHREALTIME + 2 ))
  while [[ ! -s $ZT_COMP_FILE ]] && (( EPOCHREALTIME < deadline )); do zselect -t 2; done
  zselect -t 10
  zt_pty_send $'\x18\x04'
  deadline=$(( EPOCHREALTIME + 10 ))
  while [[ ! -e $ZT_COMP_FILE.done ]] && (( EPOCHREALTIME < deadline )); do zselect -t 2; done
  [[ -e $ZT_COMP_FILE.done ]] || zt_fail "completion of ${(qqqq)1} did not finish"
  zt_pty_keys $'\x15\r'
  reply=()
  [[ -s $ZT_COMP_FILE ]] && reply=( "${(@f)$(<$ZT_COMP_FILE)}" )
}

# The matches alone, without descriptions, sorted and space separated, in REPLY.
zt_matches() {
  local -a m
  m=( "${(@u)reply%%$'\t'*}" )
  m=( "${(@o)m}" )
  REPLY=${(j: :)m}
}

assert_offered() {   # match...
  local -a got=( "${reply[@]%%$'\t'*}" ) m
  for m in "$@"; do
    (( ${got[(Ie)$m]} )) || zt_fail "not offered: $m" "  offered: ${(j:, :)got}"
  done
}

assert_not_offered() {   # match...
  local -a got=( "${reply[@]%%$'\t'*}" ) m
  for m in "$@"; do
    (( ${got[(Ie)$m]} )) && zt_fail "offered but should not be: $m" "  offered: ${(j:, :)got}"
  done
  return 0
}

# @scenario shell-completion: Complete options
test_complete_options() {
  zt_comp_start
  zt_complete 'opus -'
  zt_pty_stop
  assert_offered -n -c -m -v -q -e -a -s -r -h
  local o line
  for o in -n -c -m -v -q -e -a -s -r -h; do
    line=${(M)reply:#$o$'\t'*}
    assert_ne "$line" '' "$o has a description"
  done
}

# @scenario shell-completion: Complete long options
test_complete_long_options() {
  zt_comp_start
  zt_complete 'opus --app'
  zt_pty_stop
  zt_matches
  assert_eq "$REPLY" '--append-system-prompt --append-system-prompt-file'
}

# @scenario shell-completion: Complete line-mode options
test_complete_line_mode_options() {
  zt_comp_start
  zt_complete 'opus --sh'
  zt_pty_stop
  zt_matches
  assert_eq "$REPLY" '--shell --show-config'
}

# @scenario shell-completion: Directory completion for --add-dir
test_directory_completion_for_add_dir() {
  mkdir lib && touch lib.md
  zt_comp_start
  zt_complete 'opus --add-dir li'
  zt_pty_stop
  assert_offered lib
  assert_not_offered lib.md
}

test_file_completion_for_file_options() {
  touch style.md
  zt_comp_start
  zt_complete 'opus --append-system-prompt-file sty'
  zt_complete 'opus --settings=sty'
  zt_pty_stop
  assert_offered style.md
}

# @scenario shell-completion: Permission modes
test_permission_modes() {
  zt_comp_start
  zt_complete 'opus --permission-mode a'
  zt_pty_stop
  zt_matches
  assert_eq "$REPLY" 'acceptEdits auto'
}

test_free_text_values_offer_nothing() {
  touch reviewer.md
  zt_comp_start
  zt_complete 'opus --agent rev'
  zt_pty_stop
  assert_eq $#reply 0 "no completions for an agent name"
}

# @scenario shell-completion: Complete effort word
test_complete_effort_word() {
  zt_comp_start
  zt_complete 'opus x'
  zt_pty_stop
  assert_offered xhigh
  assert_not_offered ultracode
}

test_no_effort_words_once_an_effort_is_set() {
  zt_comp_start
  zt_complete 'opus high x'
  zt_pty_stop
  assert_not_offered xhigh
}

# @scenario shell-completion: Complete level after -e
test_complete_level_after_e() {
  zt_comp_start
  zt_complete 'sonnet -e '
  zt_pty_stop
  zt_matches
  assert_eq "$REPLY" 'high low max medium xhigh'
}

# @scenario shell-completion: Complete a file name in the prompt
test_complete_a_file_name_in_the_prompt() {
  touch README.md
  zt_comp_start
  zt_complete 'sonnet edit REA'
  zt_pty_stop
  assert_offered README.md
}

test_options_are_not_offered_after_the_prompt_starts() {
  zt_comp_start
  zt_complete 'opus explain -'
  zt_pty_stop
  assert_not_offered -n -e
}

# @scenario shell-completion: Complete a model for zco
test_complete_a_model_for_zco() {
  zt_comp_start
  zt_complete 'zco so'
  assert_offered sonnet
  assert_not_offered opus
  zt_complete 'zco sonnet -e '
  zt_pty_stop
  assert_offered high
}

# @scenario shell-completion: Completion initialised after the plugin
test_completion_initialised_after_the_plugin() {
  zt_comp_start late
  zt_pty_run 'true'               # the first prompt registers the completion
  zt_complete 'opus -'
  zt_pty_stop
  assert_offered -n -e -s
}

# @scenario shell-completion: COMPLETE_ALIASES set
test_complete_aliases_set() {
  zt_comp_start 'setopt COMPLETE_ALIASES'
  zt_complete 'opus -e '
  zt_pty_stop
  zt_matches
  assert_eq "$REPLY" 'high low max medium xhigh'
}

test_prefixed_commands_complete() {
  zt_comp_start 'ZCO_PREFIX=c-'
  zt_complete 'c-opus --max-b'
  zt_pty_stop
  assert_offered --max-budget-usd
}
