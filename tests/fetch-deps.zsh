#!/usr/bin/env zsh
# Clone the line-editor plugins used by the coexistence tests into tests/.deps/, at pinned tags.
#   zsh tests/fetch-deps.zsh
# Without them, the coexistence tests are skipped with a notice.

emulate zsh

typeset -g ZD_DIR=${0:A:h}/.deps

zd_main() {
  local name url tag
  local -a deps
  deps=(
    zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git 0.8.0
    zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions.git     v0.7.1
  )
  mkdir -p -- $ZD_DIR
  for name url tag in $deps; do
    if [[ -d $ZD_DIR/$name ]]; then
      print -r -- "$name: already present"
      continue
    fi
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch $tag -- $url $ZD_DIR/$name || return 1
    print -r -- "$name: cloned at $tag"
  done
}

zd_main "$@"
