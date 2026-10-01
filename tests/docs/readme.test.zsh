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

test_keys_table_matches_the_key_schema() {
  zt_readme_section $ZT_README keys-table
  assert_eq "$REPLY" "$(zt_readme_keys_table)" "README keys table is stale: run zsh tests/update-readme.zsh"
}

# The fenced block between two README markers, written to a file.
zt_readme_example() {   # marker file
  zt_readme_section $ZT_README $1
  local -a lines
  lines=( "${(@f)REPLY}" )
  lines=( "${(@)lines:#\`\`\`*}" )
  assert_ne $#lines 0 "README example $1 not found"
  mkdir -p -- ${2:h}
  print -rl -- "${lines[@]}" > $2
}

test_readme_example_user_file_parses() {
  zt_readme_example example-user-config ~/.zco.config
  zt_settings opus summarize
  assert_eq $ZT_RC 0 "$REPLY"
  assert_setting effort xhigh '~/.zco.config:7'
  assert_setting permission_mode acceptEdits
  assert_setting append_system_prompt_file "$HOME/.config/zco/house-style.md"
  zt_settings haiku summarize
  assert_setting max_budget_usd 0.10
  assert_setting session_persistence false
}

test_readme_example_project_file_parses() {
  zt_readme_example example-project-config ~/proj/.zco.config
  cd ~/proj
  zt_settings opus summarize
  assert_eq $ZT_RC 0 "$REPLY"
  assert_setting agent reviewer '~/proj/.zco.config:2'
  zt_list "$S[add_dir]"; assert_eq "${(j:|:)reply}" "$HOME/shared-lib"
  zt_list "$S[allowed_tools]"; assert_eq "${(j:|:)reply}" 'Bash(git *)|Edit'
}

test_readme_format_example_parses() {
  zt_readme_example example-format-config ~/.zco.config
  zt_settings opus summarize
  assert_eq $ZT_RC 0 "$REPLY"
  assert_setting effort xhigh
  assert_setting append_system_prompt 'Use # for headings. '
}
