# zsh-claude-oneshot: one-shot Claude Code prompts from zsh, one command per model.
# Load it with a plugin manager or with `source /path/to/zsh-claude-oneshot.plugin.zsh`.

# Zsh Plugin Standard: find this file even when sourced through a symlink or a plugin manager.
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

() {
  emulate -L zsh
  local dir=${1:A:h}

  (( ${fpath[(Ie)$dir/functions]} )) || fpath=( $dir/functions $fpath )
  local -a fns
  fns=( $dir/functions/[^.]*(N.:t) )
  (( $#fns )) && autoload -Uz $fns
  return 0
} "$0"
