# _zco_classify: the token classifier shared by the parser, the line rewrite and completion.

zt_functions

zt_class() {   # token effort_set expected
  local -A zk
  _zco_keys
  _zco_classify "$1" "$2"
  assert_eq "$REPLY" "$3" "class of ${(qqqq)1} (effort set: $2)"
}

test_end_of_options() {
  zt_class -- 0 end
  zt_class -- 1 end
}

test_effort_words_only_while_no_effort_is_set() {
  local w
  for w in low medium high xhigh max; do
    zt_class $w 0 effort
    zt_class $w 1 prompt
  done
  zt_class High 0 prompt
  zt_class XHIGH 0 prompt
}

test_options_that_take_a_value() {
  local o
  for o in -e -a -s -r --effort --agent --skill --resume --permission-mode --system-prompt \
           --system-prompt-file --append-system-prompt --append-system-prompt-file --add-dir \
           --allowed-tools --disallowed-tools --settings --mcp-config --fallback-model \
           --max-turns --max-budget-usd; do
    zt_class $o 0 value-opt
  done
}

test_long_options_with_equals() {
  zt_class --effort=low 0 value-eq
  zt_class --effort= 0 value-eq
  zt_class --agent= 0 value-eq
  zt_class '--system-prompt=Be terse.' 0 value-eq
  zt_class --dry-run=yes 0 unknown
  zt_class --nope=1 0 unknown
}

test_flags_and_bundles() {
  local o
  for o in -n -c -m -v -q -h --dry-run --continue --mcp --verbose --quiet --help \
           --show-config --shell --literal -nc -cn -ncmvqh -vq; do
    zt_class $o 0 flag
  done
}

test_unknown_options() {
  local o
  for o in -x --x -ne -en -nx --Shell -; do
    [[ $o == - ]] && continue
    zt_class $o 0 unknown
  done
}

test_ultracode_and_prompt_words() {
  zt_class ultracode 0 ultracode
  zt_class ultracode 1 ultracode
  zt_class - 0 prompt
  zt_class commit 0 prompt
  zt_class '' 0 prompt
  zt_class 'two words' 0 prompt
  zt_class ';' 0 prompt
}
