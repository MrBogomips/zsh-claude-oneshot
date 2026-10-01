#!/usr/bin/env zsh
# Test runner for zsh-claude-oneshot.
#
#   zsh tests/run.zsh [PATH...]     run every *.test.zsh under PATH (default: tests/)
#   zsh tests/run.zsh --lint [PATH...]   run `zsh -n` on every zsh file (default: the repository)
#
# Each test file runs in a fresh `zsh -f`, each test function in its own subshell, with a
# temporary HOME and the Claude Code test double first on PATH. Output is TAP-style.
# ZT_JOBS sets how many files run in parallel (default 4). Directories named `fixtures` or
# `.deps` are skipped during discovery; pass a file or directory explicitly to include it.

emulate zsh
setopt extended_glob

typeset -g ZT_TESTS=${0:A:h}
typeset -g ZT_ROOT=${ZT_TESTS:h}

zt_discover() {   # paths...: files matching the pattern below each directory, in $reply
  local pattern=$1 p f rel
  shift
  reply=()
  for p in "$@"; do
    if [[ -d $p ]]; then
      for f in $p/**/${~pattern}(N.); do
        rel=${f#$p/}
        [[ $rel == ((*/|)fixtures/*|(*/|).deps/*|(*/|).git/*) ]] && continue
        reply+=( $f )
      done
    elif [[ -f $p ]]; then
      reply+=( $p )
    else
      print -ru2 -- "run.zsh: no such file or directory: $p"
      return 2
    fi
  done
}

zt_lint() {
  local -a files targets
  local f
  integer bad=0
  targets=( "$@" )
  (( $#targets )) || targets=( $ZT_ROOT )
  for f in $targets; do
    if [[ -d $f ]]; then
      zt_discover '*.zsh' $f || return 2
      files+=( $reply $f/functions/*(N.) $f/tests/bin/*(N.) )
    else
      files+=( $f )
    fi
  done
  for f in $files; do
    if zsh -n -- $f; then
      print -r -- "ok - zsh -n ${f#$ZT_ROOT/}"
    else
      print -r -- "not ok - zsh -n ${f#$ZT_ROOT/}"
      bad+=1
    fi
  done
  print -r -- "1..0 # lint: $#files files, $bad with syntax errors"
  (( bad == 0 ))
}

zt_utf8_locale() {
  local l
  for l in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
    if [[ -n ${(M)${(f)"$(locale -a 2>/dev/null)"}:#$l} ]]; then
      print -r -- $l
      return
    fi
  done
  print -r -- en_US.UTF-8
}

# Refuse to run unless `claude` resolves to the test double, so no test can reach the real CLI.
zt_guard() {
  local found
  found=$(whence -p claude)
  if [[ $found != $ZT_TESTS/bin/claude ]] || ! grep -q 'zco-test-double' -- $found 2>/dev/null; then
    print -r -- "Bail out! \`claude\` resolves to ${found:-nothing}, not the test double $ZT_TESTS/bin/claude"
    return 1
  fi
}

zt_main() {
  if [[ $1 == --lint ]]; then
    shift
    zt_lint "$@"
    return
  fi

  local -a files
  zt_discover '*.test.zsh' ${@:-$ZT_TESTS} || return 2
  files=( $reply )

  path=( $ZT_TESTS/bin $path )
  export PATH
  zt_guard || return 2

  export ZT_ROOT ZT_TESTS ZT_OUTER_HOME=$HOME
  export ZT_UTF8_LOCALE=${ZT_UTF8_LOCALE:-$(zt_utf8_locale)}

  local work f line
  work=$(mktemp -d "${TMPDIR:-/tmp}/zt-run.XXXXXX") || return 2
  integer i jobs_max=${ZT_JOBS:-4} n=0 failed=0 skipped=0
  local -a pids
  for (( i = 1; i <= $#files; i++ )); do
    f=$files[i]
    zsh -f $ZT_TESTS/lib/runfile.zsh $f ${f#$ZT_ROOT/} > $work/$i.out 2>&1 &
    pids+=( $! )
    if (( $#pids >= jobs_max )); then
      wait $pids[1]
      pids=( $pids[2,-1] )
    fi
  done
  wait

  integer results
  for (( i = 1; i <= $#files; i++ )); do
    results=0
    while IFS= read -r line; do
      case $line in
        ('not ok '*) n+=1; results+=1; failed+=1; print -r -- "not ok $n ${line#not ok }" ;;
        ('ok '*'# SKIP'*) n+=1; results+=1; skipped+=1; print -r -- "ok $n ${line#ok }" ;;
        ('ok '*) n+=1; results+=1; print -r -- "ok $n ${line#ok }" ;;
        (*) print -r -- $line ;;
      esac
    done < $work/$i.out
    if (( results == 0 )); then
      n+=1; failed+=1
      print -r -- "not ok $n - ${files[i]#$ZT_ROOT/}: (no results: the file runner crashed)"
    fi
  done
  rm -rf -- $work
  print -r -- "1..$n"
  print -r -- "# $n tests: $(( n - failed - skipped )) passed, $failed failed, $skipped skipped"
  (( failed == 0 && n > 0 ))
}

zt_main "$@"
