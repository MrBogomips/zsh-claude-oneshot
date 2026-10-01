# Property test for the never-pass rule: runs _zco_main for every combination of
#   - the options -n -c -m -v -q (all 32 subsets),
#   - six effort sources,
#   - nine settings of the booleans mcp and session_persistence,
#   - the extra_args values given to zt_property,
# and checks that none of the never-pass flags is ever among the Claude Code arguments, and that
# a run with a forbidden extra_args value fails with status 2 without running Claude Code.
# Claude Code is replaced by a function that records its arguments, so nothing is spawned.

typeset -ga ZT_NEVER=( --bare --safe-mode --dangerously-skip-permissions --allow-dangerously-skip-permissions )

zt_property_record() { print -rn -- "${(pj:\0:)@}" > $ZT_TMP/recorded }

zt_property() {   # extra_args value... (use - for "no extra_args")
  local extra effort bools flags_mask flag rc forbidden
  local -a flags efforts boolsets words got
  integer runs=0 mask
  flags=( -n -c -m -v -q )
  efforts=( none word option env env-model file-section )
  boolsets=( '' 'ZCO_MCP=1' 'ZCO_MCP=0' 'ZCO_SESSION_PERSISTENCE=yes' 'ZCO_SESSION_PERSISTENCE=off'
             'ZCO_MCP=yes ZCO_SESSION_PERSISTENCE=no' 'ZCO_MCP=off ZCO_SESSION_PERSISTENCE=on'
             'ZCO_MCP=true ZCO_SESSION_PERSISTENCE=true' 'ZCO_MCP=false ZCO_SESSION_PERSISTENCE=false' )
  local PATH=$ZT_TESTS/bin   # no jq: progress stays off, so nothing is spawned
  export ZCO_CLAUDE_CMD=zt_property_record

  for extra in "$@"; do
    forbidden=0
    if [[ $extra != - ]]; then
      _zco_extra_ok "$extra" || forbidden=1
    fi
    for effort in $efforts; do
      {
        [[ $extra != - ]] && print -r -- "extra_args = $extra"
        [[ $effort == file-section ]] && print -r -- $'[opus]\neffort = medium'
      } > $HOME/.zco.config
      for bools in "${boolsets[@]}"; do
        unset ZCO_MCP ZCO_SESSION_PERSISTENCE ZCO_EFFORT ZCO_EFFORT_OPUS
        [[ -n $bools ]] && export ${=bools}
        case $effort in
          (env) export ZCO_EFFORT=high ;;
          (env-model) export ZCO_EFFORT_OPUS=max ;;
        esac
        for (( mask = 0; mask < 32; mask++ )); do
          words=()
          for (( i = 1; i <= 5; i++ )); do
            (( mask & (1 << (i - 1)) )) && words+=( $flags[i] )
          done
          case $effort in
            (word) words+=( xhigh ) ;;
            (option) words+=( -e low ) ;;
          esac
          : > $ZT_TMP/recorded
          _zco_main opus opus $words do the thing </dev/null >/dev/null 2>$ZT_TMP/stderr
          rc=$?
          runs+=1
          if (( forbidden )); then
            (( rc == 2 )) || zt_fail "forbidden extra_args $extra: status $rc for: opus ${words[*]} ($bools)"
            [[ -s $ZT_TMP/recorded ]] && zt_fail "forbidden extra_args $extra: Claude Code ran for: opus ${words[*]}"
            continue
          fi
          (( rc == 0 )) || zt_fail "status $rc for: opus ${words[*]} ($bools, effort $effort, extra $extra)" "$(<$ZT_TMP/stderr)"
          got=( "${(@0)$(<$ZT_TMP/recorded)}" )
          for flag in $got; do
            [[ $flag == -- ]] && break
            (( ${ZT_NEVER[(Ie)${flag%%=*}]} )) && zt_fail "never-pass flag $flag passed for: opus ${words[*]}"
          done
        done
      done
    done
  done
  print -r -- "property runs: $runs"
  (( runs == $# * 6 * 9 * 32 )) || zt_fail "expected $(( $# * 6 * 9 * 32 )) runs, made $runs"
}
