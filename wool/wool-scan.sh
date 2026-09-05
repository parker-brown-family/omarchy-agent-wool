#!/bin/sh
# Enrich the wall. Runs ONLY while the wall is open — the panel's timer is the
# only caller — because everything here that costs anything (the herdr mirror,
# the vitals CLI reading whole transcripts) is priced for a surface someone is
# actually looking at. Terminal Delight once shipped this sweep ungated and
# read 3.5MB/s of disk with the wall closed. The gate is the design.
#
# Writes one file:
#
#   ${XDG_STATE_HOME:-~/.local/state}/omarchy/wool/wall.json
#
#   { "stamp": <epoch>, "vitals": { "<herd key>": {window,fatigue,relevance,
#                                    call,tokens,limit,model,effort,...} } }
#
# A session with no measurable vitals is ABSENT from the map — never zeroed.
# The panel renders absence as absence.
set -eu

HERD="${WOOL_HERD_BIN:-herd}"
TD="${WOOL_TD_BIN:-terminal-delight}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/herd/state.json"
OUT_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/wool"
OUT="$OUT_DIR/wall.json"
LOCK="$OUT_DIR/.lock"

mkdir -p "$OUT_DIR"

TMP="$OUT.tmp.$$"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT INT TERM HUP

# One scan at a time. A bar per monitor means a panel per monitor, and every
# open panel ticks; the slowest acceptable outcome of that is one slightly
# stale file, never a pile-up of vitals processes.
exec 9>"$LOCK"
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || exit 0
fi

# Refresh the herdr mirror first, so the wall the reader is looking at shows
# herdr's agents at wall-tick freshness. Absent herd, absent herdr: fine —
# the mirror just does not move.
if command -v "$HERD" >/dev/null 2>&1; then
  "$HERD" sync-herdr 2>/dev/null || true
fi

VITALS='[]'
if [ -f "$STATE" ] && command -v "$TD" >/dev/null 2>&1; then
  # Transcript paths come from herd's file. They are filesystem paths written
  # by our own hooks, but they still get an existence check before reaching a
  # command line, and they are passed as argv entries, never re-parsed.
  set --
  while IFS= read -r t; do
    [ -f "$t" ] && set -- "$@" "$t"
  done <<EOF
$(jq -r '.sessions[] | select(.transcript != null) | .transcript' "$STATE" 2>/dev/null || true)
EOF
  if [ "$#" -gt 0 ]; then
    VITALS=$("$TD" agent-vitals "$@" 2>/dev/null) || VITALS='[]'
    printf '%s' "$VITALS" | jq -e 'type == "array"' >/dev/null 2>&1 || VITALS='[]'
  fi
fi

# The vitals CLI keys its rows by session uuid, which IS the herd key for
# self-reported entries. herdr-mirrored entries carry no transcript and are
# simply not in the map.
printf '%s' "$VITALS" | jq -c --argjson stamp "$(date +%s)" '
  {
    stamp: $stamp,
    vitals: (map({ key: .session, value: . }) | from_entries)
  }' >"$TMP" 2>/dev/null || printf '{"stamp":%s,"vitals":{}}\n' "$(date +%s)" >"$TMP"

# Rename within the directory: a watching reader never sees half a file.
mv -f "$TMP" "$OUT"
