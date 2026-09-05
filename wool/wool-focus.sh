#!/bin/sh
# Take the human to the agent behind a card.
#
#   wool-focus.sh <key>
#
# Keys are herd's: a Claude session uuid, or "herdr:<pane_id>" for a mirrored
# herdr agent. Two focus paths, then one small write:
#
#   herdr:*  →  herdr agent focus <pane>, then raise the herdr client's window
#   uuid     →  climb the agent process's /proc ancestry to the first pid
#               Hyprland owns, and raise that window
#
# then `herd seen <key>`, which is the write that ends "finished-and-unseen".
# Every failure path exits 0 and does nothing: a jump that cannot land must
# not crash a bar.
#
# The raise machinery — Lua dispatcher first with legacy fallback, token and
# address hygiene, the /proc walk — is adapted from the Crook tray's focus
# script (né omarchy-herd/herd-focus.sh; same author, same licence), where
# each piece carries a lesson already paid for.
set -eu

KEY="${1:-}"
HERD="${WOOL_HERD_BIN:-herd}"
HERDR="${WOOL_HERDR_BIN:-herdr}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/herd/state.json"

# Anything outside this shape did not come from herd, and nothing outside
# this shape reaches a command line.
valid_token() {
  case "${1:-}" in
    "") return 1 ;;
    *[!A-Za-z0-9:._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

valid_address() {
  case "${1:-}" in
    0x*) ;;
    *) return 1 ;;
  esac
  case "${1#0x}" in
    "" | *[!0-9a-fA-F]*) return 1 ;;
    *) return 0 ;;
  esac
}

valid_token "$KEY" || exit 0

# Hyprland 0.56 replaced string dispatchers with a Lua API, and the old form
# fails quietly there (exit 7, parse error). Try new, fall back to legacy.
raise() {
  hyprctl dispatch "hl.dsp.focus({window=\"$1\"})" >/dev/null 2>&1 \
    || hyprctl dispatch focuswindow "$1" >/dev/null 2>&1 \
    || true
}

# Field 4 of /proc/<pid>/stat is the parent pid; the comm field ahead of it is
# parenthesised and may contain anything, so read after the last ')'.
ppid_of() {
  [ -r "/proc/$1/stat" ] || return 1
  sed 's/^.*)//' "/proc/$1/stat" 2>/dev/null | awk '{ print $2 }'
}

# The window for a process is its first ancestor Hyprland owns: an agent runs
# under a shell under a terminal, and the terminal is the client.
window_of() {
  _pid=$1
  _hops=0
  while [ "$_hops" -lt 32 ]; do
    case "$_pid" in
      "" | *[!0-9]*) return 1 ;;
    esac
    [ "$_pid" -gt 1 ] || return 1
    _addr=$(printf '%s\n' "$WINDOWS" | awk -v p="$_pid" '$1 == p { print $2; exit }')
    if [ -n "$_addr" ]; then
      printf '%s\n' "$_addr"
      return 0
    fi
    _pid=$(ppid_of "$_pid") || return 1
    _hops=$(( _hops + 1 ))
  done
  return 1
}

load_windows() {
  command -v hyprctl >/dev/null 2>&1 || return 1
  WINDOWS=$(hyprctl clients -j 2>/dev/null \
    | jq -r '.[]? | select(.pid != null and .address != null) | "\(.pid) \(.address)"' \
    2>/dev/null) || WINDOWS=''
  [ -n "$WINDOWS" ]
}

raise_from_pid() {
  load_windows || return 0
  addr=$(window_of "$1") || return 0
  valid_address "$addr" || return 0
  raise "address:$addr"
}

case "$KEY" in
  herdr:*)
    pane="${KEY#herdr:}"
    valid_token "$pane" || exit 0
    "$HERDR" agent focus "$pane" >/dev/null 2>&1 || exit 0
    # herdr's focus moves inside its own terminal; when that terminal sits on
    # another workspace, nothing visible happens without a raise. Any herdr
    # client's window is the right one — they all live in the same terminal
    # session's window per client.
    if command -v pgrep >/dev/null 2>&1 && load_windows; then
      HERDR_NAME=${HERDR##*/}
      if valid_token "$HERDR_NAME"; then
        for candidate in $(pgrep -x "$HERDR_NAME" 2>/dev/null || true); do
          addr=$(window_of "$candidate") || continue
          valid_address "$addr" || continue
          raise "address:$addr"
          break
        done
      fi
    fi
    ;;
  *)
    [ -f "$STATE" ] || exit 0
    pid=$(jq -r --arg k "$KEY" \
      '[.sessions[] | select(.key == $k) | .pid] | first // empty' \
      "$STATE" 2>/dev/null) || exit 0
    case "$pid" in
      "" | *[!0-9]*) exit 0 ;;
    esac
    raise_from_pid "$pid"
    ;;
esac

# Looking at an agent is what turns "done" into "idle". Best effort; a wall
# whose herd has vanished still focuses fine.
if command -v "$HERD" >/dev/null 2>&1; then
  "$HERD" seen "$KEY" 2>/dev/null || true
fi
