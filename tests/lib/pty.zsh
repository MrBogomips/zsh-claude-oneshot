# Drives an interactive `zsh -i` under zpty, for tests that need a terminal and the line editor.
#
#   zt_pty_start [zshrc-line...]   start the shell; the lines are appended to its .zshrc
#   zt_pty_run LINE [TIMEOUT]      type LINE, press Enter, wait for the next prompt;
#                                  the output in between is in $ZT_PTY_OUT (cleaned)
#   zt_pty_send TEXT               send raw keys without Enter
#   zt_pty_wait [TIMEOUT]          wait for the next prompt; output in $ZT_PTY_OUT
#   zt_pty_stop                    end the shell
#
# The shell runs with ZDOTDIR=$ZT_TMP/zdotdir, no global rc files, TERM=dumb, and the prompt
# set to a marker so the end of each command can be detected.

zmodload zsh/zpty zsh/zselect zsh/datetime

typeset -g ZT_PTY_MARK='<ZT-PROMPT>'
typeset -g ZT_PTY_BUF= ZT_PTY_OUT=

zt_pty_start() {
  local zdot=$ZT_TMP/zdotdir
  mkdir -p -- $zdot
  {
    print -r -- "PS1='$ZT_PTY_MARK'; PS2='<ZT-CONT>'; RPS1=''"
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

zt_pty_wait() {   # [timeout seconds]
  setopt local_options extended_glob
  local chunk
  typeset -F deadline=$(( EPOCHREALTIME + ${1:-10} ))
  while [[ $ZT_PTY_BUF != *"$ZT_PTY_MARK"* ]]; do
    if zpty -rt ZT chunk 2>/dev/null; then
      ZT_PTY_BUF+=$chunk
      continue
    fi
    (( EPOCHREALTIME > deadline )) && { zt_pty_clean "$ZT_PTY_BUF"; ZT_PTY_OUT=$REPLY; return 1 }
    zselect -t 2
  done
  zt_pty_clean "${ZT_PTY_BUF%%"$ZT_PTY_MARK"*}"
  ZT_PTY_OUT=$REPLY
  ZT_PTY_BUF=${ZT_PTY_BUF#*"$ZT_PTY_MARK"}
  return 0
}

zt_pty_send() { zpty -w -n ZT "$1" }

zt_pty_run() {   # line [timeout]
  zpty -w -n ZT "$1"$'\r'
  zt_pty_wait ${2:-10} || zt_fail "zpty: no prompt after typing ${(qqqq)1}" "  output: ${(qqqq)ZT_PTY_OUT}"
  # Drop the echo of the typed line itself.
  ZT_PTY_OUT=${ZT_PTY_OUT#*$'\n'}
}

zt_pty_stop() { zpty -d ZT 2>/dev/null; return 0 }
