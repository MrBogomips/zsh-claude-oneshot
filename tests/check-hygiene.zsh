#!/usr/bin/env zsh
# Repository hygiene: fails on absolute home-directory paths and on AI attribution trailers or
# "generated with" notes.   (hygiene: allow)
#
#   zsh tests/check-hygiene.zsh [FILE...]
#
# Without arguments it checks every file git tracks or would track (untracked files that are not
# ignored). A line that only describes these patterns can carry the marker `hygiene: allow`.
# The patterns are assembled from pieces so that this script does not match itself.

emulate zsh
setopt extended_glob

typeset -g ZH_ROOT=${0:A:h:h}

zh_main() {
  local -a files patterns
  if (( $# )); then
    files=( "$@" )
  else
    files=( ${(f)"$(git -C $ZH_ROOT ls-files --cached --others --exclude-standard 2>/dev/null)"} )
    if (( ! $#files )); then
      print -ru2 -- "check-hygiene: no files found (is $ZH_ROOT a git repository?)"
      return 2
    fi
    files=( $ZH_ROOT/${^files}(N.) )
  fi

  local co='co-authored' by='-by:' gen='generated' sess='-session:' vendor='anthropic'
  patterns=(
    '(^|[^[:alnum:]._-])/(Users|home)/'
    "${co}${by}"
    "claude${sess}"
    "${gen} with"
    "${gen} by (an? )?(claude|${vendor}|chatgpt|gpt|copilot|codex|gemini|ai)([^[:alnum:]]|\$)"
    "noreply@${vendor}"
    'claude[.]ai/code'
    $'\U0001F916'
  )

  local -a hits
  hits=( ${(f)"$(grep -H -n -i -E ${patterns/#/-e} -- $files 2>/dev/null)"} )
  hits=( ${hits:#*hygiene: allow*} )

  local hit
  for hit in $hits; do
    print -r -- "hygiene: ${hit#$ZH_ROOT/}"
  done
  print -r -- "# hygiene: $#files files checked, $#hits problems"
  (( $#hits == 0 ))
}

zh_main "$@"
