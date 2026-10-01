# Drives an interactive `zsh -i` under zpty, for tests that need a terminal and the line editor.
#
#   zt_pty_start [zshrc-line...]   start the shell; the lines are appended to its .zshrc
#   zt_pty_run LINE [TIMEOUT]      type LINE, press Enter, wait for the next prompt;
#                                  the output in between is in $ZT_PTY_OUT (cleaned)
#                                  and $ZT_PTY_RAW (with escape sequences)
#   zt_pty_send TEXT               send raw keys without Enter
#   zt_pty_wait [TIMEOUT] [MARKER] wait for the next prompt (or MARKER); output in $ZT_PTY_OUT
#   zt_pty_keys KEYS [MARKER]      send raw keys, then wait for the prompt (or MARKER)
#   zt_pty_stop                    end the shell
#
# The shell runs with ZDOTDIR=$ZT_TMP/zdotdir, no global rc files and TERM=dumb.

zmodload zsh/zpty zsh/zselect zsh/datetime

# The end of a command is marked by a precmd hook, which runs once per new prompt; the prompt
# itself is not used, because line-editor plugins redraw it.
typeset -g ZT_PTY_MARK='<ZT-READY>'
typeset -g ZT_PTY_BUF= ZT_PTY_OUT= ZT_PTY_RAW=

zt_pty_start() {
  local zdot=$ZT_TMP/zdotdir
  mkdir -p -- $zdot
  {
    print -r -- "PS1='<ZT-PROMPT>'; PS2='<ZT-CONT>'; RPS1=''"
    print -r -- "zt_ready() { print -rn -- '$ZT_PTY_MARK' }; precmd_functions+=( zt_ready )"
    print -r -- "unset zle_bracketed_paste; unsetopt prompt_sp; PROMPT_EOL_MARK=''"
    print -r -- "HISTFILE=${(q)ZT_TMP}/history; HISTSIZE=200; SAVEHIST=200"
    print -rl -- "$@"
  } > $zdot/.zshrc
  ZT_PTY_BUF=
  zpty -b ZT "TERM=dumb ZDOTDIR=${(q)zdot} zsh -o no_global_rcs -i" || zt_fail "zpty: cannot start zsh -i"
  zt_pty_wait 15 || zt_fail "zpty: no first prompt" "  output: ${(qqqq)ZT_PTY_OUT}"
}

# Remove carriage returns, backspaces with what they erase, and terminal escape sequences.
zt_pty_clean() {
  setopt local_options extended_glob
  local s=$1
  s=${s//$'\r'/}
  s=${s//$'\e'\[[0-9;?]#[A-Za-z]/}
  while [[ $s == *?$'\b'* ]]; do s=${s/?$'\b'/}; done
  REPLY=$s
}

zt_pty_wait() {   # [timeout seconds] [marker]: wait for the marker (default: the prompt)
  setopt local_options extended_glob
  local chunk mark=${2:-$ZT_PTY_MARK}
  typeset -F deadline=$(( EPOCHREALTIME + ${1:-10} ))
  while [[ $ZT_PTY_BUF != *"$mark"* ]]; do
    if zpty -rt ZT chunk 2>/dev/null; then
      ZT_PTY_BUF+=$chunk
      continue
    fi
    (( EPOCHREALTIME > deadline )) && { zt_pty_clean "$ZT_PTY_BUF"; ZT_PTY_OUT=$REPLY; return 1 }
    zselect -t 2
  done
  ZT_PTY_RAW=${ZT_PTY_BUF%%"$mark"*}
  zt_pty_clean "$ZT_PTY_RAW"
  ZT_PTY_OUT=$REPLY
  ZT_PTY_BUF=${ZT_PTY_BUF#*"$mark"}
  return 0
}

# Send raw keys, then wait for MARKER (default: the prompt). Output in $ZT_PTY_OUT.
zt_pty_keys() {   # keys [marker] [timeout]
  zpty -w -n ZT "$1"
  zt_pty_wait ${3:-10} "${2:-$ZT_PTY_MARK}" || zt_fail "zpty: no ${(qqqq)${2:-prompt}} after sending ${(qqqq)1}" "  output: ${(qqqq)ZT_PTY_OUT}"
}

zt_pty_send() { zpty -w -n ZT "$1" }

zt_pty_run() {   # line [timeout]
  zpty -w -n ZT "$1"$'\r'
  zt_pty_wait ${2:-10} || zt_fail "zpty: no prompt after typing ${(qqqq)1}" "  output: ${(qqqq)ZT_PTY_OUT}"
  # Drop the echo of the typed line itself.
  ZT_PTY_OUT=${ZT_PTY_OUT#*$'\n'}
}

zt_pty_stop() { zpty -d ZT 2>/dev/null; return 0 }
