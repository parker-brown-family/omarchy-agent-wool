# Changelog

## 0.2.0 — 2026-09-05

The family found its true names, and Wool follows: the state bus is **Herd**
(was crook; `~/.local/state/herd/state.json`, verbs `herd sync-herdr` /
`herd seen`), and the attention tray is **Crook** (was the Herd plugin).
Wool's job is unchanged — it reads the bus and draws the flock. Also:
home-directory sessions title their card `~`, and the README wears the first
live wall.

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
