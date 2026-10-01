#!/usr/bin/env zsh
# Spec-scenario coverage: every `#### Scenario:` heading in the OpenSpec change specs and main
# specs needs at least one test tagged `# @scenario <capability>: <scenario name>`.
#
#   zsh tests/scenario-coverage.zsh [--specs DIR]... [--tests DIR]...
#
# DIR for --specs holds <capability>/spec.md files; the default is every active change's specs/
# plus openspec/specs/. The default for --tests is tests/ (directories named `fixtures` or
# `.deps` are skipped). Tags naming no known scenario are errors too. Exits 1 on any gap.

emulate zsh
setopt extended_glob

typeset -g ZC_TESTS=${0:A:h}
typeset -g ZC_ROOT=${ZC_TESTS:h}

zc_main() {
  local tests_dir=$ZC_TESTS root=$ZC_ROOT
  local -a spec_dirs test_dirs
  while (( $# )); do
    case $1 in
      (--specs) spec_dirs+=( ${2:?--specs needs a directory} ); shift 2 ;;
      (--tests) test_dirs+=( ${2:?--tests needs a directory} ); shift 2 ;;
      (*) print -ru2 -- "scenario-coverage: unknown argument: $1"; return 2 ;;
    esac
  done
  if (( ! $#spec_dirs )); then
    spec_dirs=( $root/openspec/changes/^archive/specs(N/) $root/openspec/specs(N/) )
  fi
  (( $#test_dirs )) || test_dirs=( $tests_dir )

  # Scenarios: "capability: name" -> "file:line"
  local -A scenarios
  local d f cap line key
  integer n
  for d in $spec_dirs; do
    for f in $d/*/spec.md(N.); do
      cap=${f:h:t}
      n=0
      while IFS= read -r line || [[ -n $line ]]; do
        n+=1
        if [[ $line == (#b)'#### Scenario:'[[:space:]]#(*[^[:space:]])[[:space:]]# ]]; then
          key="$cap: $match[1]"
          scenarios[$key]=$f:$n
        fi
      done < $f
    done
  done

  # Tags: "capability: name" -> count
  local -A tagged
  local rel
  integer unknown=0
  for d in $test_dirs; do
    for f in $d/**/*.zsh(N.); do
      rel=${f#$d/}
      [[ $rel == ((*/|)fixtures/*|(*/|).deps/*) ]] && continue
      n=0
      while IFS= read -r line || [[ -n $line ]]; do
        n+=1
        if [[ $line == (#b)[[:space:]]#'#'[[:space:]]#'@scenario'[[:space:]]##([^:]##):[[:space:]]#(*[^[:space:]])[[:space:]]# ]]; then
          key="$match[1]: $match[2]"
          if (( ${+scenarios[$key]} )); then
            (( tagged[$key]++ ))
          else
            print -r -- "UNKNOWN ${f#$root/}:$n $key"
            unknown+=1
          fi
        fi
      done < $f
    done
  done

  integer missing=0 total=${#scenarios}
  for key in ${(ko)scenarios}; do
    if (( ! ${+tagged[$key]} )); then
      print -r -- "MISSING $key  (${scenarios[$key]#$root/})"
      missing+=1
    fi
  done

  integer covered=$(( total - missing ))
  print -r -- "# scenario coverage: $covered/$total$( (( total )) && print -r -- " ($(( covered * 100 / total ))%)" ), $unknown unknown tags"
  (( total > 0 && missing == 0 && unknown == 0 ))
}

zc_main "$@"
