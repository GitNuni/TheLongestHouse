# The Longest House

Co-op (2–4 player) first-person bodycam survival horror. Police officers respond
to a disturbance call at a suburban house that turns out to be a cult front —
the interior is non-euclidean and expands as the summoning ritual escalates.
Fight cultists, evade unbeatable ghosts, log evidence via bodycam, Lethal
Company-style run loop (10–20 min runs).

**The design source of truth is `docs/GDD.md`** — read it before making design
decisions. (`docs/GDD.pdf` is the original Revision 2 document; the markdown
version supersedes it where they differ, e.g. the engine choice.)

**House generation and non-euclidean escalation are specified in
`docs/design/house_and_corruption.md`** — read it before touching the
generator, corruption, or set-piece systems. Key laws: the house must make
sense before corrupting (canonical ranch plan is in the doc); connections lie
before rooms do; wrongness follows the deniability curve (tiers 0–3); the
front door never lies; runs start outside at the police cruiser; the haunting
leaks outside further with each consecutive shift.

## Engine

- **Godot 4.7 (stable)**, Forward+ renderer, GDScript.
- Decision context: chosen over UE5 (which the original GDD named) for the
  beginner-friendly workflow, text-based scenes/scripts, built-in high-level
  multiplayer API, and fit with the PS2-retro art direction.
- Official docs reference: shallow-clone into the session when needed —
  `git clone --depth 1 https://github.com/godotengine/godot-docs.git /home/user/godot-docs`
  (session containers are ephemeral; the clone does not persist). Class
  reference lives in `classes/`, tutorials in `tutorials/`.

## Team context

3-person team, all new to game development and largely new to coding. When
working with them:

- Explain *why*, not just *what* — they are learning the engine through this
  project. Prefer teaching moments over magic.
- Keep changes small and reviewable; avoid clever GDScript when plain GDScript
  will do.

## Conventions

- Typed GDScript everywhere (`var health: int = 3`, typed function signatures).
- snake_case for files/dirs, PascalCase for node names and class_name.
- Scene organization: one scene per logical unit; keep scenes small and
  composable.
- Directory layout (grows as needed):
  - `scenes/` — .tscn scenes
  - `scripts/` — shared/standalone .gd scripts (scene-specific scripts live
    next to their scene)
  - `assets/` — models, textures, audio
  - `docs/` — GDD and design notes

## Milestones (from GDD)

1. **Core Wrongness Prototype** — single hallway-loop "bigger on the inside"
   moment. No combat/ghosts/evidence. Solo-testable. ← current target
2. **Co-op Foundation** — 2 players in the same warping house, shared state.
3. **Threats** — cultist combat + one ghost with client-side evasion.
4. **Evidence & Loop** — logging, dispatch radio, quota win/fail, shift reset.
5. **Procedural House Layouts** — assembled room/hallway pieces per run.
6. **Content & Polish.**

Key design pillar: **asymmetric horror, symmetric world** — objective state is
replicated/shared; ghost encounters are individually experienced (client-side),
which is both a horror choice and a netcode simplification.
