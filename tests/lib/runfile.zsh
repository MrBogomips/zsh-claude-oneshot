# Runs the tests of one *.test.zsh file: zsh -f tests/lib/runfile.zsh FILE [LABEL]
# Prints one TAP-style line per test (unnumbered; tests/run.zsh numbers them) plus `#` diagnostics.

emulate zsh
source ${0:A:h}/harness.zsh

zt_list_tests() {   # file: test function names in file order, in $reply
  setopt local_options extended_glob
  local line
  reply=()
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line == (#b)[[:space:]]#(function[[:space:]]##|)(test_[A-Za-z0-9_]##)[[:space:]]#(\(\)|\{)* ]]; then
      reply+=( $match[2] )
    fi
  done < $1
}

zt_runfile_main() {
  local file=$1 label=${2:-$1} t log rc reason
  local work
  work=$(mktemp -d "${TMPDIR:-/tmp}/zt-file.XXXXXX") || return 2
  export ZT_TMPROOT=$work

  if ! source $file > $work/load.log 2>&1; then
    print -r -- "not ok - $label: (loading the file failed)"
    sed 's/^/# /' $work/load.log
    rm -rf -- $work
    return 1
  fi

  zt_list_tests $file
  if (( ! $#reply )); then
    print -r -- "not ok - $label: (no test_* functions found)"
    rm -rf -- $work
    return 1
  fi

  local -i failed=0
  for t in $reply; do
    log=$work/$t.log
    export ZT_FAILFILE=$work/$t.fail ZT_SKIPFILE=$work/$t.skip
    (
      zt_begin_test
      [[ -n ${ZT_KEEP:-} ]] || trap 'cd /; rm -rf -- "$ZT_TMP"' EXIT
      $t
    ) > $log 2>&1 < /dev/null
    rc=$?
    if [[ -s $ZT_SKIPFILE ]]; then
      reason=$(<$ZT_SKIPFILE)
      print -r -- "ok - $label: $t # SKIP $reason"
    elif (( rc == 0 )) && [[ ! -s $ZT_FAILFILE ]]; then
      print -r -- "ok - $label: $t"
    else
      failed+=1
      print -r -- "not ok - $label: $t"
      [[ -s $log ]] && sed 's/^/#   /' $log
      (( rc != 0 )) && [[ ! -s $ZT_FAILFILE ]] && print -r -- "#   (exited with status $rc)"
    fi
  done
  rm -rf -- $work
  (( failed == 0 ))
}

zt_runfile_main "$@"
