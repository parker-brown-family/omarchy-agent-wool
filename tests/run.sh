#!/bin/sh
# Wool's test suite. POSIX sh, no framework, one dependency (jq) the plugin
# itself already needs. Everything runs against stubs in tests/stubs, so no
# herd, no herdr, no Hyprland and no desktop session are required — the
# parts that need those are the parts a test cannot honestly cover.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
STUBS="$ROOT/tests/stubs"
PATH="$STUBS:$PATH"
export PATH

PASS=0
FAIL=0

pass() { PASS=$(( PASS + 1 )); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$(( FAIL + 1 )); printf '  FAIL %s\n       %s\n' "$1" "$2"; }

check() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected [$2], got [$3]"; fi
}

check_contains() {
  case "$3" in
    *"$2"*) pass "$1" ;;
    *) fail "$1" "expected to contain [$2], got [$3]" ;;
  esac
}

section() { printf '\n%s\n' "$1"; }

# A fresh state directory per test, and a fixture herd file with three
# entries: two self-reported claude sessions with transcripts, one mirrored
# herdr codex with none.
sandbox() {
  SANDBOX=$(mktemp -d)
  export SANDBOX
  HOME="$SANDBOX/home"
  XDG_STATE_HOME="$SANDBOX/state"
  WOOL_STUB_LOG="$SANDBOX/stub.log"
  WOOL_HERD_BIN="$STUBS/herd"
  WOOL_TD_BIN="$STUBS/terminal-delight"
  WOOL_HERDR_BIN="$STUBS/herdr"
  export HOME XDG_STATE_HOME WOOL_STUB_LOG WOOL_HERD_BIN WOOL_TD_BIN WOOL_HERDR_BIN
  unset WOOL_STUB_TD_MODE WOOL_STUB_WINPID WOOL_STUB_HYPR 2>/dev/null || true
  mkdir -p "$HOME" "$XDG_STATE_HOME/herd"
  : >"$SANDBOX/aaaa-1111.jsonl"
  : >"$SANDBOX/bbbb-2222.jsonl"
  cat >"$XDG_STATE_HOME/herd/state.json" <<EOF
{
  "herd": { "version": "0.1.0", "engine": 1 },
  "updated_at": 1000,
  "sessions": [
    { "key": "aaaa-1111", "agent": "claude-code", "state": "working", "source": "self",
      "cwd": "/tmp/projA", "pid": $$, "transcript": "$SANDBOX/aaaa-1111.jsonl",
      "title": "fix the tests", "updated_at": 1000 },
    { "key": "bbbb-2222", "agent": "claude-code", "state": "done", "source": "self",
      "cwd": "/tmp/projB", "transcript": "$SANDBOX/bbbb-2222.jsonl", "updated_at": 1000 },
    { "key": "herdr:w1:p2", "agent": "codex", "state": "blocked", "source": "herdr",
      "cwd": "/tmp/projC", "updated_at": 1000, "stale_after": 9999999999 }
  ]
}
EOF
  WALL_JSON="$XDG_STATE_HOME/omarchy/wool/wall.json"
}

scan() { sh "$ROOT/wool/wool-scan.sh"; }
focus() { sh "$ROOT/wool/wool-focus.sh" "$@"; }
stub_log() { [ -f "$WOOL_STUB_LOG" ] && cat "$WOOL_STUB_LOG" || printf ''; }

# ---------------------------------------------------------------- manifest

section 'manifest.json'

check 'is valid json with the right id' 'brownfamilysports.wool' \
  "$(jq -r '.id' "$ROOT/manifest.json")"
check 'declares a bar widget entry point' 'Panel.qml' \
  "$(jq -r '.entryPoints.barWidget' "$ROOT/manifest.json")"

# --------------------------------------------------------------- wool-scan

section 'wool-scan.sh'

sandbox
scan
check 'vitals land keyed by session' '0.42' \
  "$(jq -r '.vitals["aaaa-1111"].window' "$WALL_JSON")"
check 'every transcript-bearing session is measured' '2' \
  "$(jq '.vitals | length' "$WALL_JSON")"
check 'a mirrored agent with no transcript is absent, not zeroed' 'null' \
  "$(jq -c '.vitals["herdr:w1:p2"]' "$WALL_JSON")"
check 'the snapshot is stamped' 'number' "$(jq -r '.stamp | type' "$WALL_JSON")"
check 'the herdr mirror is refreshed first' 'herd sync-herdr' \
  "$(grep '^herd' "$WOOL_STUB_LOG" | head -1)"
check 'no temporary file is left behind' '0' \
  "$(find "$XDG_STATE_HOME/omarchy/wool" -name 'wall.json.tmp*' | wc -l | tr -d ' ')"

sandbox
WOOL_TD_BIN=/nonexistent/terminal-delight scan
check 'no vitals CLI means an empty map, and still a valid file' '0' \
  "$(jq '.vitals | length' "$WALL_JSON")"

sandbox
WOOL_STUB_TD_MODE=garbage scan
check 'garbage vitals output degrades to an empty map' '0' \
  "$(jq '.vitals | length' "$WALL_JSON")"

sandbox
WOOL_HERD_BIN=/nonexistent/herd scan
check 'a missing herd still publishes the wall' '2' \
  "$(jq '.vitals | length' "$WALL_JSON")"

sandbox
rm "$XDG_STATE_HOME/herd/state.json"
scan
check 'no herd state at all publishes an empty wall, not a crash' '0' \
  "$(jq '.vitals | length' "$WALL_JSON")"

# -------------------------------------------------------------- wool-focus

section 'wool-focus.sh'

sandbox
focus 'herdr:w1:p2'
check_contains 'a mirrored key goes through herdr' 'herdr agent focus w1:p2' "$(stub_log)"
check_contains 'and the look is recorded' 'herd seen herdr:w1:p2' "$(stub_log)"

sandbox
WOOL_STUB_WINPID=$$
export WOOL_STUB_WINPID
focus 'aaaa-1111'
check_contains 'a session key raises its window by address' 'address:0xabc123' "$(stub_log)"
check_contains 'via the Lua dispatcher first' 'hl.dsp.focus' "$(stub_log)"

sandbox
WOOL_STUB_WINPID=$$
WOOL_STUB_HYPR=old
export WOOL_STUB_WINPID WOOL_STUB_HYPR
focus 'aaaa-1111'
check_contains 'and falls back to the legacy dispatcher' 'focuswindow address:0xabc123' "$(stub_log)"

sandbox
focus 'cccc-3333'
case "$(stub_log)" in
  *dispatch*) fail 'an unknown key raises nothing' "it did: $(stub_log)" ;;
  *) pass 'an unknown key raises nothing' ;;
esac

sandbox
focus 'aaaa-1111; rm -rf /'
check 'a key that is not a key is refused outright' '' "$(stub_log)"

sandbox
# shellcheck disable=SC2016  # the literal text is the point: it must not expand
focus '$(whoami)'
check 'and so is a substitution attempt' '' "$(stub_log)"

sandbox
WOOL_HERD_BIN=/nonexistent/herd
export WOOL_HERD_BIN
focus 'herdr:w1:p2'
check_contains 'focus works without herd (seen is best-effort)' 'herdr agent focus w1:p2' "$(stub_log)"

# ------------------------------------------------------------------- shape

section 'repository shape'

for f in Panel.qml FleeceFace.qml wool/wool-scan.sh wool/wool-focus.sh README.md LICENSE; do
  if [ -f "$ROOT/$f" ]; then pass "$f exists"; else fail "$f exists" "missing"; fi
done

# ----------------------------------------------------------------- summary

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
