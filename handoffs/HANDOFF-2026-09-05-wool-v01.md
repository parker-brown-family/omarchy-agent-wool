# Handoff — Wool v0.1: the wall is built, staged, and one command from the bar

**Date:** 2026-09-05 (overnight build)
**Status:** built, 27/27 tests, qmllint clean, `omarchy plugin validate` clean,
staged in the shell as **disabled** — deliberately not enabled while Parker
slept, because the one unacceptable overnight outcome was a broken bar.

## Morning checklist

```bash
omarchy plugin enable brownfamilysports.wool
```

Then add the Wool widget to the bar if placement is manual, click the 󰕰 icon,
and the wall should show the live fleet (crook has been collecting all night).
If a card is missing: that session predates the hooks and appears on its next
event. Right-click the bar icon jumps to the first agent that wants eyes.

The plugin is a symlink: `~/.config/omarchy/plugins/brownfamilysports.wool`
→ `~/Work/omarchy-agent-wool` (dev-link pattern; the repo is public at
github.com/parker-brown-family/omarchy-agent-wool, so `omarchy plugin add`
works as the non-dev install).

## What it is

Pure display over the crook bus + optional vitals enrichment. The plan,
its reshape (wool-scan became a joiner, not a detector), and per-ticket
status live in `omarchy-agent-wool-plan.html` (the TPS report, annotated).

- `Panel.qml` — bar icon with fleece-tier tallies; toggled KeyboardPanel wall
  of cards; FileView-watches crook's state.json (always) and wall.json
  (enrichment); staleness contract applied in the renderer.
- `FleeceFace.qml` — interim vector sheep-robot, white/grey/black by tier.
  A placeholder photograph: the canonical sheep art is Parker's thread in
  agent-playhouse, and arrives via the publish pipeline (plan ticket W-007).
- `wool/wool-scan.sh` — runs ONLY while the wall is open: `crook sync-herdr`,
  one batched `terminal-delight agent-vitals` call, atomic wall.json.
  Absent vitals are absent, never zeroed.
- `wool/wool-focus.sh` — herdr agents via `herdr agent focus`; everything
  else climbs /proc to the window Hyprland owns; Lua dispatcher with legacy
  fallback; then `crook seen`.

## Verified

- `sh tests/run.sh` — 27/27 against stubs (scan join, honest absence,
  garbage/missing binaries, both focus paths, both Hyprland dispatchers,
  injection refusal).
- Live scan: four real sessions measured in one vitals call, wall.json
  correct.
- qmllint: calibrated against Herd's known-good Panel (exit 0 there too).

## Not done / next

- **Enable + eyeball on the live bar** — the one step a stub cannot cover:
  KeyboardPanel sizing at Style.space(1140), Flow wrapping, theme colours.
- Sheep art publish target with `--check` (W-007) — interim face until then.
- Filter chips, multi-monitor policy, layer-shell fullscreen form — the
  plan's open questions, unchanged.
- shellcheck's mise shim is broken machine-wide (`mise use -g
  shellcheck@0.11.0` would fix); scripts mirror herd-focus.sh's
  shellcheck-clean patterns but were not machine-checked.
- The repo went public later the same day (remote on the github-bfs alias);
  open threads still live in the plan and this handoff — file them as
  `follow-up` issues here as they firm up.
