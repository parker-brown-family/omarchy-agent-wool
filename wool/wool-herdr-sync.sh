#!/bin/sh
# Mirror herdr's agents into the Herd bus, on herdr's own events.
#
# The wall already refreshes the mirror on its own tick — but only while it is
# open, which is the design and also the gap: with the wall closed, herdr's
# agents stop reaching the bus at all, so the first draw after opening it shows
# a flock as stale as the last time anyone looked. Every other display reading
# the bus (Crook, a tmux line, `herd watch`) inherits the same staleness, and
# none of them can fix it, because none of them is the wall.
#
# herdr can: it knows the moment an agent changes, and this is the whole hook.
# One verb, no arguments, no state of its own.
#
#   herd sync-herdr
#
# Best effort by construction. A plugin hook that fails loudly gets disabled by
# the thing that ran it, and a missing herd is not an error — it is a machine
# where the bus is not installed, and the wall says so honestly on its own.
set -eu

HERD="${WOOL_HERD_BIN:-herd}"

if command -v "$HERD" >/dev/null 2>&1; then
  "$HERD" sync-herdr 2>/dev/null || true
fi
