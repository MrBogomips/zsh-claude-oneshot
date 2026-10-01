# Assertions and the per-test environment for the zsh-claude-oneshot test suite.
# Sourced by tests/lib/runfile.zsh in a fresh `zsh -f`; every test runs in its own subshell.

typeset -g ZT_ROOT=${ZT_ROOT:-${${(%):-%x}:A:h:h:h}}
typeset -g ZT_TESTS=$ZT_ROOT/tests
typeset -g ZT_PLUGIN=$ZT_ROOT/zsh-claude-oneshot.plugin.zsh
typeset -g ZT_TMP= ZT_OUT= ZT_ERR=
typeset -gi ZT_RC=0

# ---------------------------------------------------------------- failures

zt_fail() {
  local msg
  for msg in "$@"; do
    print -r -- "$msg" >&2
    [[ -n ${ZT_FAILFILE:-} ]] && print -r -- "$msg" >> $ZT_FAILFILE
  done
  exit 1
}

zt_skip() {
  [[ -n ${ZT_SKIPFILE:-} ]] && print -r -- "$*" > $ZT_SKIPFILE
  exit 0
}

# ---------------------------------------------------------------- assertions

assert_eq() {   # actual expected [message]
  [[ $1 == "$2" ]] && return 0
  zt_fail "${3:-assert_eq failed}" "  expected: ${(qqqq)2}" "  actual:   ${(qqqq)1}"
}

assert_ne() {   # actual unexpected [message]
  [[ $1 != "$2" ]] && return 0
  zt_fail "${3:-assert_ne failed}" "  both are: ${(qqqq)1}"
}

assert_contains() {   # haystack needle [message]
  [[ $1 == *"$2"* ]] && return 0
  zt_fail "${3:-assert_contains failed}" "  missing:  ${(qqqq)2}" "  in:       ${(qqqq)1}"
}

assert_not_contains() {   # haystack needle [message]
  [[ $1 != *"$2"* ]] && return 0
  zt_fail "${3:-assert_not_contains failed}" "  found:    ${(qqqq)2}" "  in:       ${(qqqq)1}"
}

assert_match() {   # string pattern [message]
  [[ $1 == ${~2} ]] && return 0
  zt_fail "${3:-assert_match failed}" "  pattern:  $2" "  string:   ${(qqqq)1}"
}

assert_status() {   # expected [message]: status of the last zt_run
  (( ZT_RC == $1 )) && return 0
  zt_fail "${2:-assert_status failed}: expected status $1, got $ZT_RC" \
    "  stdout: ${(qqqq)ZT_OUT}" "  stderr: ${(qqqq)ZT_ERR}"
}

assert_true() {   # message command...
  local msg=$1; shift
  "$@" && return 0
  zt_fail "$msg"
}

assert_file_absent() {   # path [message]
  [[ ! -e $1 && ! -L $1 ]] && return 0
  zt_fail "${2:-file should not exist}: $1"
}

assert_lines_eq() {   # actual expected-line...: compares line by line
  local -a got want
  got=( "${(@f)1}" ); shift; want=( "$@" )
  [[ ${(pj:\n:)got} == ${(pj:\n:)want} ]] && return 0
  zt_fail "assert_lines_eq failed" "  expected:" "${want[@]/#/    }" "  actual:" "${got[@]/#/    }"
}

# ---------------------------------------------------------------- the Claude Code test double

# Arguments of the last (or the n-th) call to the test double, in $reply.
zt_claude_argv() {   # [n]
  local f=$FAKE_CLAUDE_LOG/argv${1:+.$1} content
  reply=()
  [[ -f $f ]] || return 1
  content=$(<$f)
  reply=( "${(@0)content}" )
  reply[-1]=()   # every argument is NUL-terminated: drop the empty tail
  return 0
}

zt_claude_calls() {   # prints how many times the double ran
  if [[ -f $FAKE_CLAUDE_LOG/count ]]; then print -r -- "$(<$FAKE_CLAUDE_LOG/count)"; else print 0; fi
}

zt_claude_stdin_kind() { REPLY=; [[ -f $FAKE_CLAUDE_LOG/stdin_kind ]] && REPLY=$(<$FAKE_CLAUDE_LOG/stdin_kind) }
zt_claude_stdin() { REPLY=; [[ -f $FAKE_CLAUDE_LOG/stdin ]] && zt_raw $FAKE_CLAUDE_LOG/stdin }

zt_claude_env() {   # name: value the double saw, in REPLY; status 1 when unset
  local f=$FAKE_CLAUDE_LOG/env line content
  REPLY=
  [[ -f $f ]] || return 1
  content=$(<$f)
  for line in "${(@0)content}"; do
    [[ $line == "$1="* ]] && { REPLY=${line#*=}; return 0 }
  done
  return 1
}

assert_argv() {   # expected argument...
  zt_claude_argv || zt_fail "assert_argv: Claude Code was not run" "  stderr: ${(qqqq)ZT_ERR}"
  [[ $#reply == $# && ${(pj:\0:)reply} == ${(pj:\0:)@} ]] && return 0
  zt_fail "assert_argv: arguments differ" "  expected: ${(j: :)${(@qqqq)@}}" "  actual:   ${(j: :)${(@qqqq)reply}}"
}

assert_argv_has() {   # word...: the words appear consecutively in the recorded argv
  zt_claude_argv || zt_fail "assert_argv_has: Claude Code was not run" "  stderr: ${(qqqq)ZT_ERR}"
  local hay=$'\0'${(pj:\0:)reply}$'\0' needle=$'\0'${(pj:\0:)@}$'\0'
  [[ $hay == *"$needle"* ]] && return 0
  zt_fail "assert_argv_has: missing ${(j: :)${(@qqqq)@}}" "  argv: ${(j: :)${(@qqqq)reply}}"
}

assert_argv_lacks() {   # word: the word is not among the recorded arguments
  zt_claude_argv || zt_fail "assert_argv_lacks: Claude Code was not run" "  stderr: ${(qqqq)ZT_ERR}"
  (( ${reply[(Ie)$1]} == 0 )) && return 0
  zt_fail "assert_argv_lacks: found ${(qqqq)1}" "  argv: ${(j: :)${(@qqqq)reply}}"
}

assert_not_run() {   # [message]
  [[ ! -f $FAKE_CLAUDE_LOG/count ]] && return 0
  zt_fail "${1:-Claude Code should not have run}" "  stderr: ${(qqqq)ZT_ERR}"
}

# ---------------------------------------------------------------- running commands

# Exact file content (trailing newlines kept) in REPLY.
zt_raw() { REPLY=$(cat -- "$1"; print -n .); REPLY=${REPLY%.} }

zt_collect() {
  ZT_OUT=$(<$ZT_TMP/.stdout)
  ZT_ERR=$(<$ZT_TMP/.stderr)
}

# ZT_USER_OPTIONS (e.g. "ksh_arrays sh_word_split no_unset err_exit") simulates a user's shell
# options: they are set around each command run by zt_run*, and the run fails if the command
# leaves the options changed. The options are set in an inner function that always returns 0,
# because a non-zero return with err_exit set would end the test shell.
zt__with_options() {
  setopt local_options ${=ZT_USER_OPTIONS}
  # local_options is inherited by called functions and would hide any option they change, so it
  # is off while the command runs; set again before returning, it restores the caller's options.
  unsetopt local_options
  ZT__BEFORE=$(setopt)
  "$@" || ZT__RC=$?
  ZT__AFTER=$(setopt)
  setopt local_options
}

zt__invoke() {
  if [[ -z ${ZT_USER_OPTIONS:-} ]]; then
    "$@"
    return
  fi
  typeset -g ZT__BEFORE= ZT__AFTER=
  typeset -gi ZT__RC=0
  zt__with_options "$@"
  [[ $ZT__BEFORE == "$ZT__AFTER" ]] || zt_fail "the command changed the shell options" \
    "  before: ${(j:, :)${(f)ZT__BEFORE}}" "  after:  ${(j:, :)${(f)ZT__AFTER}}"
  return ZT__RC
}

# Run a command in the current shell with stdin from /dev/null; sets ZT_OUT, ZT_ERR and ZT_RC.
zt_run() {
  zt__invoke "$@" </dev/null >$ZT_TMP/.stdout 2>$ZT_TMP/.stderr
  ZT_RC=$?
  zt_collect
  return 0
}

# Same, with stdin redirected from a file.
zt_run_stdin() {   # file command...
  local in=$1; shift
  zt__invoke "$@" <$in >$ZT_TMP/.stdout 2>$ZT_TMP/.stderr
  ZT_RC=$?
  zt_collect
  return 0
}

# Same, with data piped into the command (the command still runs in the current shell).
zt_run_pipe() {   # data command...
  local data=$1; shift
  print -rn -- "$data" | zt__invoke "$@" >$ZT_TMP/.stdout 2>$ZT_TMP/.stderr
  ZT_RC=$?
  zt_collect
  return 0
}

# Run a command line as typed (aliases expand); for the per-model commands.
zt_line() { zt_run eval "$1" }

# ---------------------------------------------------------------- fixtures

zt_write() {   # path content: writes content plus a final newline, creating directories
  mkdir -p -- ${1:h}
  print -r -- "$2" > $1
}

zt_user_config() { zt_write $HOME/.zco.config "$1" }

zt_load() { source $ZT_PLUGIN }

# The per-model command names the plugin defined, sorted and space separated.
zt_cmd_names() {
  local -a names
  names=( ${(k)_zco_cmds} )
  print -r -- ${(j: :)${(o)names}}
}

# Autoload the plugin's functions without loading the plugin (for unit tests).
zt_functions() {
  local -a fns
  fpath=( $ZT_ROOT/functions $fpath )
  fns=( $ZT_ROOT/functions/[^.]*(N.:t) )
  (( $#fns )) && autoload -Uz $fns
}

# Parse arguments with _zco_parse: results in the global assoc P, status in ZT_RC, message in REPLY.
zt_parse() {
  typeset -gA P
  P=()
  local -A zk
  _zco_keys
  _zco_parse "$@"
  ZT_RC=$?
}

# Elements of a parsed or configured list value (NUL-terminated entries), in $reply.
zt_list() { reply=( ${(0)1} ) }

# Parse ARG..., then find, read and resolve the configuration for MODEL with _zco_settings.
# Results: globals P, S (values), Ssrc (sources), Slayer (layers), zco_files (user, project);
# status in ZT_RC, message in REPLY.
zt_settings() {   # model arg...
  typeset -gA P S Ssrc Slayer
  typeset -ga zco_files
  P=() S=() Ssrc=() Slayer=() zco_files=()
  local -A zk
  _zco_keys
  if ! _zco_parse "${@:2}"; then
    ZT_RC=2
    return 0
  fi
  zt__invoke _zco_settings $1
  ZT_RC=$?
  return 0
}

# Run `zco ARG...` in this shell (stdin /dev/null); the plugin must be loaded.
zt_zco() { zt_run zco "$@" }

# stderr of the last run without the header line (the first line, when it holds " · " or " - ").
zt_stderr_body() {
  local -a lines
  lines=( "${(@f)ZT_ERR}" )
  [[ ${lines[1]:-} == *(' · '|' - ')* ]] && lines[1]=()
  REPLY=${(pj:\n:)lines}
}

assert_stderr_body_empty() {   # [message]
  zt_stderr_body
  [[ -z $REPLY ]] && return 0
  zt_fail "${1:-stderr should hold nothing but the header}" "  stderr: ${(qqqq)ZT_ERR}"
}

assert_setting() {   # key value [source]
  assert_eq "${S[$1]-<unset>}" "$2" "value of $1"
  (( $# < 3 )) || assert_eq "${Ssrc[$1]-<unset>}" "$3" "source of $1"
}

zt_mkdir_cd() { mkdir -p -- $1 && cd -- $1 }

# Set PATH to the test double plus links to the few tools it needs, so that jq is not found.
zt_path_without_jq() {
  local dir=$ZT_TMP/nojq-bin tool
  mkdir -p -- $dir
  for tool in zsh env mkdir cp cat; do
    ln -sf -- "$(whence -p $tool)" $dir/$tool
  done
  path=( $ZT_TESTS/bin $dir )
  export PATH
}

# A copy of a stream fixture with the fixtures' /work/proj replaced by the current directory.
zt_stream_here() {   # fixture-name: path of the copy, in REPLY
  REPLY=$ZT_TMP/${1}
  sed "s|/work/proj|$PWD|g" $ZT_TESTS/fixtures/$1 > $REPLY
}

# ---------------------------------------------------------------- per-test environment

zt_begin_test() {
  ZT_TMP=$(mktemp -d "${ZT_TMPROOT:-${TMPDIR:-/tmp}}/zt.XXXXXX") || exit 1
  ZT_TMP=${ZT_TMP:A}
  local -a leak
  leak=( ${(k)parameters[(I)ZCO_*]} ${(k)parameters[(I)FAKE_CLAUDE_*]} )
  (( $#leak )) && unset $leak
  unset NO_COLOR CLAUDE_CONFIG_DIR ANTHROPIC_DEFAULT_OPUS_MODEL
  export HOME=$ZT_TMP/home TMPDIR=$ZT_TMP/tmp FAKE_CLAUDE_LOG=$ZT_TMP/claude
  mkdir -p -- $HOME $TMPDIR
  [[ -n ${ZT_UTF8_LOCALE:-} ]] && export LC_ALL=$ZT_UTF8_LOCALE
  cd -- $HOME
}
