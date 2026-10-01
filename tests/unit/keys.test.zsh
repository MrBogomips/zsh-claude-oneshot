# _zco_keys: the single schema of configuration keys and command-line options.

zt_functions

ZT_KEY_SPEC=$ZT_ROOT/openspec/changes/add-oneshot-model-commands/specs/configuration/spec.md
[[ -f $ZT_KEY_SPEC ]] || ZT_KEY_SPEC=$ZT_ROOT/openspec/specs/configuration/spec.md

# Rows of the key table in the configuration spec, as "keys|value|cli|project" lines in $reply.
zt_spec_key_rows() {
  local line in_table=0
  reply=()
  while IFS= read -r line; do
    if [[ $line == '| key | value | command-line form | allowed in a project file |' ]]; then
      in_table=1
      continue
    fi
    (( in_table )) || continue
    [[ $line == '|---'* ]] && continue
    [[ $line == '|'* ]] || break
    reply+=( "$line" )
  done < $ZT_KEY_SPEC
}

zt_backticked() {   # text: the `quoted` words in order, in $reply
  setopt local_options extended_glob
  local s=$1
  reply=()
  while [[ $s == (#b)[^'`']#'`'([^'`']##)'`'(*) ]]; do
    reply+=( $match[1] )
    s=$match[2]
  done
}

test_key_table_matches_the_configuration_spec_row_by_row() {
  local -A zk
  _zco_keys
  zt_spec_key_rows
  local -a rows=( $reply ) spec_keys cells keys clis forms
  assert_ne $#rows 0 "the key table was not found in $ZT_KEY_SPEC"
  local row k cli i project
  for row in $rows; do
    cells=( "${(@s:|:)row}" )
    cells=( "${(@)cells[2,-2]}" )
    zt_backticked "$cells[1]"; keys=( $reply )
    zt_backticked "$cells[3]"; clis=( ${(M)reply:#-*} )
    project=${cells[4]//[[:space:]]/}
    for (( i = 1; i <= $#keys; i++ )); do
      k=$keys[i]
      spec_keys+=( $k )
      assert_ne "${zk[type:$k]:-}" '' "$k: missing from _zco_keys"
      if [[ $project == no ]]; then
        assert_eq "${zk[user:$k]:-}" 1 "$k: must be user-file only"
      else
        assert_eq "${zk[user:$k]:-}" '' "$k: must be allowed in a project file"
      fi
      if [[ $cells[2] == *'list of'* ]]; then
        assert_eq "${zk[list:$k]:-}" 1 "$k: must be a list"
        assert_eq "${zk[env:$k]:-}" '' "$k: list keys have no environment variable"
      else
        assert_eq "${zk[list:$k]:-}" '' "$k: must be a scalar"
        assert_eq "${zk[env:$k]:-}" "ZCO_${(U)k}" "$k: environment variable"
      fi
      if [[ ${cells[3]} == *—* ]]; then
        assert_eq "${zk[cli:$k]:-}" '' "$k: has no command-line form"
      elif (( $#keys > 1 && $#clis == $#keys )); then
        forms=( ${(s: :)zk[cli:$k]} )
        assert_true "$k: command-line form $clis[i]" eval '(( ${forms[(Ie)$clis[i]]} ))'
      else
        forms=( ${(s: :)zk[cli:$k]} )
        for cli in $clis; do
          assert_true "$k: command-line form $cli" eval '(( ${forms[(Ie)$cli]} ))'
        done
      fi
    done
  done
  assert_eq "${zk[keys]}" "${(j: :)spec_keys}" "schema order must follow the spec table"
}

test_defaults_and_load_time_keys() {
  local -A zk
  _zco_keys
  assert_eq "${zk[default:models]}" 'fable opus sonnet haiku'
  assert_eq "${zk[default:permission_mode]}" auto
  assert_eq "${zk[default:session_persistence]}" true
  assert_eq "${zk[default:mcp]}" false
  assert_eq "${zk[default:claude_cmd]}" claude
  assert_eq "${zk[default:raw_line]}" literal
  assert_eq "${zk[load:models]}${zk[load:prefix]}${zk[load:raw_line]}" 111
  assert_eq "${zk[path:add_dir]}${zk[path:mcp_config]}${zk[path:system_prompt_file]}${zk[path:append_system_prompt_file]}" 1111
}

test_command_line_options() {
  local -A zk
  _zco_keys
  local o
  for o in -n -c -m -v -q -h -e -a -s -r; do
    assert_ne "${zk[long:$o]:-}" '' "short option $o"
  done
  assert_eq "${zk[long:-e]}" --effort
  assert_eq "${zk[arg:--effort]}" LEVEL
  assert_eq "${zk[arg:--dry-run]:-}" ''
  assert_eq "${zk[dest:--agent]}" agent
  assert_eq "${zk[dest:--skill]}" skill
  assert_eq "${zk[dest:--resume]}" resume
  assert_eq "${zk[comp:--add-dir]}" dir
  assert_eq "${zk[comp:--permission-mode]}" mode
  assert_eq "${zk[comp:--settings]}" file
  assert_eq "${zk[bundle]}" ncmvqh
  for o in ${(s: :)zk[opts]}; do
    assert_ne "${zk[odesc:$o]:-}" '' "$o has a description"
  done
  local -a opts=( ${(s: :)zk[opts]} )
  assert_true "--shell and --literal are options" eval '(( ${opts[(Ie)--shell]} && ${opts[(Ie)--literal]} ))'
}
