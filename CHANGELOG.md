# Changelog

## Unreleased

- The widget is **Agent Wool** on the bar and at the top of the wall, and its
  icon is the sheep. Both moved here from the tray next door: Crook wore the
  sheep only because Nerd Fonts carries no shepherd's crook, and now that Crook
  draws its own, the flock belongs on the surface that draws the flock. The
  grid glyph it replaces described the layout rather than the subject.
- `qs ipc call brownfamilysports.wool toggle` works again. The widget set
  `manageIpc: false` while declaring no handler of its own, which unregistered
  the target the README tells you to bind a key to — the panel drew fine, so
  nothing looked broken until you tried the documented command and got
  `Target not found`. The base class manages the target again.
- The README carries the footprint disclosure an unsandboxed plugin owes its
  reader: every program Wool runs as an argv line, what it reads (the bus, its
  own wall file, `/proc/<pid>/stat` — not your transcripts, whose paths it
  hands to `terminal-delight agent-vitals`), the single file it writes, and no
  network at all. The list is pinned by the suite from both ends, so it cannot
  drift from the code, and CI plants a network call to prove the check works.

## 0.2.0 — 2026-09-05

The family found its true names, and Wool follows: the state bus is **Herd**
(was crook; `~/.local/state/herd/state.json`, verbs `herd sync-herdr` /
`herd seen`), and the attention tray is **Crook** (was the Herd plugin).
Wool's job is unchanged — it reads the bus and draws the flock. Also:
home-directory sessions title their card `~`, and the README wears the first
live wall. CI arrives with it — the suite, `shellcheck`, and a mutation step
that proves the tests can fail — and one of the key-validation tests was
rewritten after that step showed it passed with the guard deleted.

## 0.1.0 — 2026-09-05

First cut of the wall.

- Bar icon with fleece-tier tallies (white / grey / black), active when
  anything wants eyes; right-click jumps straight to the first such agent.
- Toggled wall of agent cards: interim sheep-robot face coloured by tier,
  project, agent kind, last prompt, state, and vitals bars (context window ·
  fatigue · relevance) when `terminal-delight agent-vitals` is available —
  an honest `— no vitals —` when it is not.
- All state from the crook bus (`~/.local/state/crook/state.json`); the
  staleness contract (`stale_after` → unknown) applied in the renderer.
- `wool-scan.sh` enrichment gated on the wall being open; flock-coalesced
  across per-monitor panels; atomic publishes.
- `wool-focus.sh`: herdr agents via `herdr agent focus`, everything else by
  climbing /proc to the window Hyprland owns; Lua dispatcher with legacy
  fallback; token and address hygiene throughout; `crook seen` on arrival.
- Stub-driven test suite (`tests/run.sh`).
