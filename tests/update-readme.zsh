#!/usr/bin/env zsh
# Rewrite the README tables that are built from _zco_keys (options and configuration keys).
#   zsh tests/update-readme.zsh

emulate zsh
typeset -g ZT_ROOT=${0:A:h:h}
fpath=( $ZT_ROOT/functions $fpath )
autoload -Uz $ZT_ROOT/functions/[^.]*(N.:t)
source $ZT_ROOT/tests/lib/readme.zsh

readme=$ZT_ROOT/README.md
tmp=$readme.tmp.$$
zt_readme_replace $readme options-table "$(zt_readme_options_table)" > $tmp && mv -- $tmp $readme
zt_readme_replace $readme keys-table "$(zt_readme_keys_table)" > $tmp && mv -- $tmp $readme
print -r -- "updated $readme"
