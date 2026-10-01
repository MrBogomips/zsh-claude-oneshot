# zsh-claude-oneshot: one-shot Claude Code prompts from zsh, one command per model.
# Load it with a plugin manager or with `source /path/to/zsh-claude-oneshot.plugin.zsh`.

# Zsh Plugin Standard: find this file even when sourced through a symlink or a plugin manager.
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

() {
  emulate -L zsh
  local dir=${1:A:h}

  (( ${+functions[is-at-least]} )) || autoload -Uz is-at-least
  if ! is-at-least 5.3; then
    print -ru2 -- "zsh-claude-oneshot: zsh 5.3 or newer is required (this is $ZSH_VERSION); nothing was loaded"
    return 1
  fi

  typeset -g _zco_dir=$dir
  (( ${fpath[(Ie)$dir/functions]} )) || fpath=( $dir/functions $fpath )
  local -a fns
  fns=( $dir/functions/[^.]*(N.:t) )
  fns=( ${fns:#zco} )            # zco is defined by _zco_define, after a collision check
  (( $#fns )) && autoload -Uz $fns

  # Load-time keys (models, prefix, raw_line): the environment, else the user file.
  local -A zk cfg cfg_src
  local -a models
  local prefix user=${ZCO_CONFIG:-$HOME/.zco.config}
  _zco_keys
  _zco_config_read -l $user user

  if (( ${+ZCO_MODELS} )); then
    if [[ ${(t)ZCO_MODELS} == array* ]]; then models=( "${ZCO_MODELS[@]}" ); else models=( ${=ZCO_MODELS} ); fi
  elif (( ${+cfg[user||models]} )); then
    models=( ${=cfg[user||models]} )
  else
    models=( ${=zk[default:models]} )
  fi
  if (( ${+ZCO_PREFIX} )); then prefix=$ZCO_PREFIX; else prefix=${cfg[user||prefix]-}; fi

  typeset -g _zco_raw_line_file=${cfg[user||raw_line]-}
  if (( ${+ZCO_RAW_LINE} )); then
    _zco_raw_mode "$ZCO_RAW_LINE" ||
      print -ru2 -- "zsh-claude-oneshot: ZCO_RAW_LINE='$ZCO_RAW_LINE' is not literal, shell or off; using literal"
  elif [[ -n $_zco_raw_line_file ]] && ! _zco_raw_mode "$_zco_raw_line_file"; then
    print -ru2 -- "zsh-claude-oneshot: ${cfg_src[user||raw_line]}: raw_line = $_zco_raw_line_file is not literal, shell or off; using literal"
    _zco_raw_line_file=literal
  fi

  _zco_define "$prefix" "${models[@]}"
  return 0
} "$0"
