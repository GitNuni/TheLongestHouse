# The Longest House

*Working title: **Disturbance at the Longer House***

Co-op (2–4 player) first-person bodycam survival horror. You're a police
officer responding to a disturbance call at an ordinary suburban house. It is
not ordinary, and it is much, much bigger on the inside.

- Fight cultists. Evade the ghosts their ritual keeps calling back.
- Log evidence on your bodycam to find the ritual's anchor point.
- The exit is always there — but leaving under quota just means another shift,
  and the ritual has kept going while you were away.

Full design: [docs/GDD.md](docs/GDD.md)

## Getting started (team)

1. Install [Godot 4.7 (stable)](https://godotengine.org/download) — the
   standard build, not the .NET one.
2. Clone this repo.
3. Open Godot, click **Import**, and select `project.godot` in the repo root.

## Tech

- **Engine:** Godot 4.7, Forward+ renderer, GDScript
- **Platform:** PC (Windows), v1
- **Art direction:** PS2-era retro (low-poly + fog), modern dynamic lighting

## Repo layout

| Path | What lives there |
| --- | --- |
| `docs/` | GDD and design notes |
| `scenes/` | Godot scenes (`.tscn`) |
| `scripts/` | Shared GDScript |
| `assets/` | Models, textures, audio |
