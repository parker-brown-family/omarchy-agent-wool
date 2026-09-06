# Wool

**The whole flock on one wall.** An Omarchy bar plugin that shows every coding
agent on the machine as a card — a face whose colour says how it's doing, the
last prompt it was given, and its context vitals — with a click that takes you
to that agent's window.

![The wall: eight live agents, attention first](docs/wall.png)

Wool is the presence third of the shepherd family:

- **[Herd](https://github.com/parker-brown-family/herd)** is the *flock's
  state itself* — the local agent-state bus everything reads.
- **[Crook](https://github.com/parker-brown-family/omarchy-crook)** is
  *attention* — the shepherd's hook that singles out the one agent that needs
  you, from the bar.
- **Wool** is *presence* — the whole flock's coat, on a toggled wall.

They compose. None requires the others.

## Where the truth comes from

Wool draws; it detects nothing. All state comes from
**[Herd](https://github.com/parker-brown-family/herd)**, the local
agent-state bus, which publishes one file at
`~/.local/state/herd/state.json`:

- **Agents feed the herd.** Claude Code sessions self-report through hooks
  (`herd hook`); anything can `herd report`; `herd sync-herdr` mirrors in
  the agents that cannot speak for themselves.
- **Displays drink from it.** Wool, Crook, a tmux status line, a script
  blocking on `herd watch` — one writer, many readers.
- **Looking back is the one write.** Clicking a card focuses the agent's
  window and marks it `seen`, which is what turns *finished-and-unseen* into
  plain idle.

Vitals (context window · fatigue · relevance) are an optional enrichment from
`terminal-delight agent-vitals`, read only while the wall is open. No
terminal-delight installed → cards honestly show `— no vitals —`, never a
zero-length bar.

## The fleece doctrine

The face carries exactly three colours, readable from across the room:

| Fleece | Means | States |
|---|---|---|
| **white** | all good | working, idle |
| **dark grey** | wants your eyes | blocked (a question is waiting), done-and-unseen, unknown |
| **black** | broken | error |

*Unknown is grey by definition.* An entry whose `stale_after` has passed is
rendered unknown — a guess must never draw as calm. Fine-grained state lives
in the card's text, not the fleece.

The current face is an interim vector sheep-robot; the canonical sheep art is
authored in agent-playhouse and will replace it through the publish pipeline.

## Install

```bash
omarchy plugin add https://github.com/parker-brown-family/omarchy-agent-wool
```

Then add the **Wool** widget to your bar. For Claude sessions to appear, the
herd hooks must be installed (`cargo install herd-bus`, then `herd hooks` —
see the Herd repository); herdr agents appear whenever herdr is running.

Toggle the wall from a keybinding if you like:

```bash
qs ipc call brownfamilysports.wool toggle
```

## Settings

- **Hide when no agents are reported** (default on)
- **Wall refresh interval** (default 2500ms) — how often the *open* wall
  re-syncs herdr and re-reads vitals. Nothing at all is scanned while the
  wall is closed.

## What this plugin runs, reads, and sends

Plugins are unsandboxed, so here is the whole footprint. Wool's is the largest
in the family — it is the one that execs another tool to measure things — which
is the reason to write it down rather than the reason not to.

<!-- footprint:begin -->
```
sh wool/wool-scan.sh                          panel timer, only while the wall is open
sh wool/wool-focus.sh <key>                   a card click
herd sync-herdr                               scan: mirror in the agents herdr knows
herd seen <key>                               focus: the one write — clears done-and-unseen
terminal-delight agent-vitals <transcript…>   scan: vitals, only if it is installed
herdr agent focus <pane>                      focus: jump to a mirrored agent's pane
hyprctl clients -j                            focus: map a pid to a window address
hyprctl dispatch <focus>                      focus: raise that window
pgrep -x herdr                                focus: find herdr's own client
jq                                            both: parse json
```
<!-- footprint:end -->

**Every one of those is an argv entry, never a shell string.** Transcript paths
reach `agent-vitals` as separate arguments after an existence check; the key
behind a card click is refused outright unless it matches
`[A-Za-z0-9:._-]+`, and it is checked again after the `herdr:` prefix is
stripped. Nothing else is interpolated into a command.

- **Reads:** `~/.local/state/herd/state.json` (the bus), the wall file Wool
  itself wrote, and `/proc/<pid>/stat` while climbing from an agent to the
  window that hosts it. It does **not** read your transcripts — it passes their
  paths, which the bus already carries, to `terminal-delight agent-vitals`,
  which reads them and returns numbers.
- **Writes:** one file,
  `~/.local/state/omarchy/wool/wall.json`, replaced by atomic rename, plus its
  lock beside it. Clicking a card also calls `herd seen`, which writes the
  bus's own state file — the only thing Wool changes outside its directory.
- **Network:** none, ever. No script here names a network tool, and a test
  says so, so it stays that way.
- **Nothing runs while the wall is closed.** The scan is driven by the panel's
  timer, and the panel does not tick when it is not open. That is the design,
  not an optimisation: an ungated version of this sweep once read 3.5MB/s of
  disk with nothing on screen.

The block above is checked by the test suite, so it cannot quietly drift from
the code: every program the stubs intercept must be named in it, and every
program it names must appear in a script.

## What Wool deliberately is not

Terminal Delight's in-terminal Agent Wall binds *panes*: live buffer
thumbnails, text crawl, pane restyling. Wool binds *sessions* — the unit
visible from outside a terminal's render loop — so those stay Terminal
Delight's. Wool never writes to a PTY, never screenshots a buffer, and never
restyles anything. If you want the pane-level wall, that is the reason to run
Terminal Delight.

## Tests

```bash
sh tests/run.sh
```

28 checks, stub-driven: no herd, herdr, Hyprland or desktop session required.
CI runs the same suite, `shellcheck`s both scripts as POSIX `sh`, and gutters
the key validation to confirm the tests notice — a suite that cannot fail
proves nothing.
