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

# Flags the README may mention that are not zsh-claude-oneshot options: Claude Code's own, and
# those of other commands in examples (git status --short, git diff --stat).
ZT_README_CLAUDE_FLAGS=(
  --model --strict-mcp-config --no-session-persistence --output-format --bare --safe-mode
  --dangerously-skip-permissions --allow-dangerously-skip-permissions --name --flag
  --short --stat
)

# Variables documented before the section that tests them exists. Each entry must go as soon
# as a test mentions the variable (the test below fails on a stale entry).
ZT_README_PENDING_VARS=()

zt_readme_tokens() {   # pattern: the distinct tokens of README.md matching an ERE, in $reply
  reply=( ${(u)${(f)"$(grep -oE -- "$1" $ZT_README)"}} )
}

zt_tests_mention() {   # text: some test file (not a fixture) contains it
  local f
  for f in $ZT_TESTS/**/*.zsh(N.); do
    [[ $f == (*/fixtures/*|$ZT_TESTS/docs/*) ]] && continue
    grep -qF -- "$1" $f && return 0
  done
  return 1
}

test_every_readme_option_is_in_the_help_and_a_test() {
  local usage o
  usage=$(_zco_usage opus opus)
  zt_readme_tokens '--[a-z][a-z0-9-]*[a-z0-9]'
  for o in $reply; do
    if [[ $usage == *" $o"* ]]; then
      assert_true "README option $o is used in no test" zt_tests_mention "$o"
    else
      assert_true "README mentions $o, which is neither an option nor a known Claude Code flag" \
        eval '(( ${ZT_README_CLAUDE_FLAGS[(Ie)$o]} ))'
    fi
  done
}

test_every_readme_variable_is_in_the_help_and_a_test() {
  local usage v
  usage=$(_zco_usage opus opus)
  zt_readme_tokens 'ZCO_[A-Z0-9_]+(<MODEL>)?'
  assert_ne $#reply 0
  for v in $reply; do
    if [[ $v == ZCO_EFFORT_?* ]]; then
      assert_contains "$usage" 'ZCO_EFFORT_<MODEL>'
      [[ $v == *'<MODEL>' ]] && v=ZCO_EFFORT_OPUS
    else
      assert_contains "$usage" "$v" "README variable $v is not in the help"
    fi
    if (( ${ZT_README_PENDING_VARS[(Ie)$v]} )); then
      zt_tests_mention "$v" && zt_fail "$v is tested now: remove it from ZT_README_PENDING_VARS"
      continue
    fi
    assert_true "README variable $v is used in no test" zt_tests_mention "$v"
  done
}

test_manual_install_snippet_works_in_zsh_f() {
  zt_readme_section $ZT_README install-manual
  local -a lines
  lines=( "${(@f)REPLY}" )
  lines=( "${(@)lines:#\`\`\`*}" )
  assert_eq $#lines 2 "clone line and source line"
  assert_match "$lines[1]" 'git clone https://github.com/MrBogomips/zsh-claude-oneshot ~/src/zsh-claude-oneshot'
  # Stand in for the clone with the working tree, then run the rest of the snippet as written.
  mkdir -p ~/src
  ln -s $ZT_ROOT ~/src/zsh-claude-oneshot
  zt_run zsh -f -c "${lines[2]}"
  assert_status 0
  zt_run zsh -f -c 'source ~/.zshrc && eval "haiku -n say hello"'
  assert_status 0
  assert_eq "$ZT_OUT" 'fake answer'
  assert_argv_has --model haiku --permission-mode plan
}

test_readme_header_examples_match_the_header_tests() {
  zt_readme_section $ZT_README header-examples
  local -a examples
  examples=( "${(@f)REPLY}" )
  examples=( "${(@)examples:#\`\`\`*}" )
  assert_eq $#examples 4
  local tests ex
  tests=$(<$ZT_TESTS/output/header.test.zsh)
  for ex in $examples; do
    assert_contains "$tests" "assert_eq \"\$REPLY\" '$ex'" "README header example without a test: $ex"
  done
}

test_readme_intro_header_and_progress_lines_match_the_formats() {
  local readme=$(<$ZT_README)
  assert_contains "$readme" $'opus · xhigh · auto · ~/proj\n→ Bash  git status --short\n→ Bash  git diff --stat'
}

test_each_rewrite_example_matches_the_rewrite_and_has_a_test() {
  typeset -gA _zco_cmds
  _zco_cmds=( opus opus sonnet sonnet haiku haiku )
  zt_readme_section $ZT_README rewrite-examples
  local -a lines
  lines=( "${(@f)REPLY}" )
  lines=( "${(@)lines:#\`\`\`*}" )
  assert_ne $#lines 0
  local tests typed expected
  tests=$(<$ZT_TESTS/unit/rewrite.test.zsh)$(<$ZT_TESTS/rawline/typed.test.zsh)
  integer i
  for (( i = 1; i < $#lines; i += 2 )); do
    typed=$lines[i] expected=${lines[i+1]#  → }
    [[ $expected == '(unchanged)' ]] && expected=$typed
    _zco_rewrite "$typed" literal
    assert_eq "$REPLY" "$expected" "README rewrite example: $typed"
    assert_contains "$tests" "$typed" "README example without a rewrite test: $typed"
  done
}

test_each_completion_example_has_a_completion_test() {
  zt_readme_section $ZT_README completion-examples
  local -a lines
  lines=( "${(@f)REPLY}" )
  lines=( "${(@)lines:#\`\`\`*}" )
  assert_eq $#lines 8
  local tests=$(<$ZT_TESTS/completion/complete.test.zsh) line typed
  for line in $lines; do
    typed=${line%%<Tab>*}
    assert_contains "$tests" "zt_complete '$typed'" "README completion example without a test: $typed"
  done
}
