# Markdown tables for README.md, built from _zco_keys so the documentation and the code cannot
# disagree. tests/update-readme.zsh writes them between the README markers; the docs tests
# compare them. Needs the plugin's functions autoloaded.

zt_readme_options_table() {
  local -A zk
  _zco_keys
  local o names value
  print -r -- '| Option | Value | Meaning |'
  print -r -- '|---|---|---|'
  for o in ${(s: :)zk[opts]}; do
    names="\`$o\`"
    [[ -n ${zk[short:$o]:-} ]] && names="\`${zk[short:$o]}\`, $names"
    value=${zk[arg:$o]:+\`${zk[arg:$o]}\`}
    print -r -- "| $names | ${value:-—} | ${zk[odesc:$o]} |"
  done
  print -r -- '| `--` | — | end of options: everything after it is the prompt |'
}

zt_readme_keys_table() {
  local -A zk
  _zco_keys
  local k cli env project def
  print -r -- '| Key | Meaning | Default | Command line | Environment | Project file |'
  print -r -- '|---|---|---|---|---|---|'
  for k in ${(s: :)zk[keys]}; do
    cli=${zk[cli:$k]:+\`${zk[cli:$k]// /\`, \`}\`}
    env=${zk[env:$k]:+\`${zk[env:$k]}\`}
    def=${zk[default:$k]:+\`${zk[default:$k]}\`}
    if [[ -n ${zk[user:$k]:-} ]]; then project=no
    elif [[ $k == permission_mode ]]; then project='yes, except `bypassPermissions`'
    else project=yes
    fi
    [[ -n ${zk[list:$k]:-} ]] && env='— (list)'
    print -r -- "| \`$k\` | ${zk[desc:$k]} | ${def:-—} | ${cli:-—} | ${env:-—} | $project |"
  done
}

# Print README.md with the text between `<!-- NAME:start -->` and `<!-- NAME:end -->` replaced.
zt_readme_replace() {   # file name content
  local file=$1 name=$2 content=$3 line skipping=0
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line == "<!-- ${name}:start -->" ]]; then
      print -r -- $line
      print -r -- $content
      skipping=1
    elif [[ $line == "<!-- ${name}:end -->" ]]; then
      print -r -- $line
      skipping=0
    elif (( ! skipping )); then
      print -r -- $line
    fi
  done < $file
}

# The text between two markers of a file, in REPLY.
zt_readme_section() {   # file name
  local line inside=0
  local -a lines
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line == "<!-- ${2}:start -->" ]]; then inside=1
    elif [[ $line == "<!-- ${2}:end -->" ]]; then inside=0
    elif (( inside )); then lines+=( "$line" )
    fi
  done < $1
  REPLY=${(pj:\n:)lines}
}
