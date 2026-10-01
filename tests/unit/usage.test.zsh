# _zco_usage and _zco_err. The end-to-end runs (`sonnet -h`, `c-opus -x`) are in the model-command tests.

zt_functions

test_help_goes_to_stdout_and_lists_every_option() {
  local -A zk
  _zco_keys
  zt_run _zco_usage sonnet sonnet
  assert_status 0
  assert_eq "$ZT_ERR" ''
  assert_contains "$ZT_OUT" 'usage: sonnet [effort] [options] [--] prompt...'
  local o
  for o in ${(s: :)zk[opts]}; do
    assert_contains "$ZT_OUT" "$o" "help lists $o"
    [[ -n ${zk[short:$o]:-} ]] && assert_contains "$ZT_OUT" "${zk[short:$o]}, $o"
  done
  assert_contains "$ZT_OUT" 'low medium high xhigh max'
  assert_contains "$ZT_OUT" '~/.zco.config'
  assert_contains "$ZT_OUT" '.zco.config'
  assert_contains "$ZT_OUT" 'ZCO_EFFORT_<MODEL>'
  assert_contains "$ZT_OUT" 'ZCO_CONFIG'
  assert_contains "$ZT_OUT" 'ZCO_LOCAL_CONFIG'
  local k
  for k in ${(s: :)zk[keys]}; do
    [[ -n ${zk[env:$k]} ]] && assert_contains "$ZT_OUT" "${zk[env:$k]}"
  done
}

test_help_for_zco_names_the_model_argument() {
  zt_run _zco_usage zco
  assert_contains "$ZT_OUT" 'usage: zco <model> [effort] [options] [--] prompt...'
}

test_usage_error_goes_to_stderr_with_status_2() {
  zt_run _zco_err c-opus "unknown option '-x'"
  assert_status 2
  assert_eq "$ZT_OUT" ''
  assert_match "$ZT_ERR" "c-opus: unknown option '-x'"$'\n'"usage: c-opus *"
  assert_contains "$ZT_ERR" "c-opus -h"
}

test_short_usage_line() {
  zt_run _zco_usage -s opus
  assert_eq "$ZT_OUT" "usage: opus [effort] [options] [--] prompt...   (opus -h for help)"
  zt_run _zco_usage -s zco
  assert_eq "$ZT_OUT" "usage: zco <model> [effort] [options] [--] prompt...   (zco <model> -h for help)"
}
