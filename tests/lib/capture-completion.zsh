# Sourced by an interactive test shell: records every completion match offered.
#
# compadd is wrapped: each match (and its description, after a tab) is appended to the file
# named by $ZT_COMP_FILE, then added as usual. Ctrl-X Ctrl-D writes $ZT_COMP_FILE.done, so a
# test that sends Tab and then Ctrl-X Ctrl-D knows when completion has finished.

compadd() {
  # compsys also calls compadd to compute (-O/-A) or filter (-D) matches: pass those through.
  if [[ ${@[1,(i)(-|--)]} == *-(O|A|D)\ * ]]; then
    builtin compadd "$@"
    return
  fi
  local -a __hits __dscr
  local __tmp __i __tab=$'\t'
  if (( $@[(I)-d] )); then
    __tmp=${@[$[${@[(i)-d]}+1]]}
    if [[ $__tmp == \(* ]]; then
      eval "__dscr=$__tmp"
    else
      __dscr=( "${(@P)__tmp}" )
    fi
  fi
  builtin compadd -A __hits -D __dscr "$@"
  for (( __i = 1; __i <= $#__hits; __i++ )); do
    print -r -- "${__hits[__i]}${__dscr[__i]:+$__tab${__dscr[__i]}}" >> $ZT_COMP_FILE
  done
  builtin compadd "$@"
}

# No listing and no menu: a list taller than the terminal would ask "do you wish to see all
# possibilities?", and the next key would answer it.
unsetopt auto_list auto_menu
zstyle ':completion:*' menu no

zt-completion-done() { : >> $ZT_COMP_FILE.done }
zle -N zt-completion-done
bindkey '^X^D' zt-completion-done
