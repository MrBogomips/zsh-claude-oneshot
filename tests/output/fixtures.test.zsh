# The synthetic stream-json fixtures are valid JSON, except the one deliberate plain-text line.

test_every_fixture_line_is_json_except_the_deliberate_one() {
  (( $+commands[jq] )) || zt_skip "jq is not installed"
  local f line
  integer bad=0 n
  for f in $ZT_TESTS/fixtures/stream-*.jsonl; do
    n=0
    while IFS= read -r line; do
      n+=1
      if ! print -r -- "$line" | jq -e . >/dev/null 2>&1; then
        bad+=1
        assert_eq "${f:t}:$line" 'stream-nonjson.jsonl:Warning: deliberately not JSON, as a plain-text line in the stream' \
          "only the deliberate line may fail jq -e ."
      fi
    done < $f
  done
  assert_eq $bad 1 "exactly one deliberate non-JSON line"
}
