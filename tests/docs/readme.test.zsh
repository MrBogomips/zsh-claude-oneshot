# README.md stays in step with the code and the tests.

zt_functions
source $ZT_TESTS/lib/readme.zsh

ZT_README=$ZT_ROOT/README.md

test_options_table_matches_the_key_schema() {
  zt_readme_section $ZT_README options-table
  assert_eq "$REPLY" "$(zt_readme_options_table)" "README options table is stale: run zsh tests/update-readme.zsh"
}

# Arguments of every `zt_parse ...` call in the parser tests, NUL-joined, in $reply.
zt_parser_test_calls() {
  local line
  reply=()
  while IFS= read -r line; do
    [[ $line == [[:space:]]#zt_parse\ * ]] || continue
    line=${line#*zt_parse }
    reply+=( "${(pj:\0:)${(@Q)${(z)line}}}" )
  done < $ZT_TESTS/unit/parse.test.zsh
}

test_each_grammar_example_has_a_parser_test() {
  setopt local_options extended_glob
  zt_readme_section $ZT_README grammar-examples
  local -a examples words calls
  examples=( ${(f)REPLY} )
  examples=( ${examples:#\`\`\`*} )
  assert_ne $#examples 0 "no grammar examples found"
  zt_parser_test_calls
  calls=( "${reply[@]}" )
  local ex args
  for ex in $examples; do
    ex=${ex%%[[:space:]]##\#*}          # drop the trailing comment
    words=( "${(@Q)${(z)ex}}" )
    args=${(pj:\0:)words[2,-1]}
    assert_true "no parser test for README example: $ex" eval '(( ${calls[(Ie)$args]} ))'
  done
}
