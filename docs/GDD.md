# Disturbance at the Longer House
*(working title — this is going to change)*

**GAME DESIGN DOCUMENT** — Revision 2 — Written by Nuni — July 11, 2026

> Markdown transcription of `GDD.pdf` (source of truth). Keep both in sync when the design changes.

---

## Introduction

### Game Summary Pitch

A police officer, wearing a bodycam, responds to a disturbance call at a small house in an ordinary suburban neighborhood. As the officer approaches, the house shows small wrongness — lights flickering erratically throughout. Once inside, it becomes clear the house is a front for a cult performing an active summoning ritual, and the interior is far larger and stranger than the exterior suggests. Playing with up to three friends, officers must fight off cultists, evade unbeatable ghosts summoned by the ongoing ritual, and log evidence toward stopping it — before the manifestation escalates beyond what the team can survive.

*(Subject to change as the design develops — current draft, revisit after vertical slice.)*

### Title Candidates

Current pick: **Disturbance at the Longer House** — not locked in, subject to change.

- **Last Call** — dispatch double meaning (final radio call / last chance).
- **No Backup / Unit Down / Disturbance Call** — backups, more literal dispatch-dread tone.

### Inspiration

- **Condemned: Criminal Origins (2005)** — grounded, desperate melee combat against human enemies; the feeling of a fight that is scary rather than empowering.
- **Lethal Company** — the "always-can-leave, but leaving under quota resets you into another run" loop structure; short, high-tension sessions played with friends.
- **Bodycam (2026, Reissue Games)** and found-footage horror generally — the visual language of degraded, realistic first-person footage as a horror tool in itself, not just an aesthetic layer.
- **Ready or Not** — tonal reference only. This game is explicitly NOT a tactical shooter; squad tactics and lean-and-clear mechanics are out of scope.
- **Crow Country / Fear the Spotlight** — modern PS2-era retro horror; proof that a low-poly, fog-driven look can carry a horror game commercially and critically with a small team.
- **Channel Zero: No-End House** — an ever-expanding, maze-like house that keeps revealing more rooms the deeper you go, with each room subtly stranger than the last; direct tonal and structural reference for the non-euclidean escalation.

### Player Experience

Players should feel the specific dread of being somewhere that is subtly, then overtly, wrong — while also feeling the camaraderie and shared panic of playing with friends. Horror beats should sometimes be experienced individually (asymmetric horror, symmetric world — see Concept), creating moments where one player sees or hears something the others didn't, and has to convince the group it was real.

### Platform

PC (Windows), single release target for v1. Console ports are out of scope for the first version.

### Development Software

- **Godot 4 (4.7 stable)** — *decision updated 2026-07-11, superseding the UE5 choice in the PDF (Revision 2).* Chosen for its gentle learning curve for a team new to coding, fully text-based scenes/scripts (which makes AI-assisted development dramatically more effective — Claude can read, write, and review the entire project), built-in high-level multiplayer API for the co-op networking, and a natural fit for the PS2-era retro art direction (Option A). Free and open-source.
- **Claude Code (Fable 5)** — AI pair-programming/agentic development, used heavily given all three team members are new to coding and game development.

> **Note:** `GDD.pdf` (Revision 2) still says Unreal Engine 5 in this section — the engine decision above supersedes it. Update the PDF at the next revision.

### Genre

Co-op (2–4 players) first-person survival horror. Hybrid of grounded melee/firearm combat and unbeatable-enemy evasion, structured as short, replayable runs.

### Target Audience

Broader horror fans, primarily groups of friends looking for a tense co-op experience to play together — not a niche/hardcore-only horror audience. Accessibility of the core loop (short runs, always-can-leave) matters more than difficulty for its own sake.

### Team

3-person team (all similar skill level, new to game development and largely new to coding). Development leans heavily on Claude Code/Fable for implementation support across all three members.

---

## Concept

### Gameplay Overview

Players control police officers (2–4 players, 2 as the baseline "always works" configuration) who respond to a disturbance call at a house that turns out to be a cult front. As they explore, the house reveals itself as non-euclidean — expanding and reconfiguring as an ongoing summoning ritual escalates in real time. Players face two distinct threats:

- **Cultists** — physical, fightable human enemies. Grounded, desperate combat (melee + sidearm firearm), in the spirit of Condemned rather than a tactical shooter.
- **Ghosts** — unbeatable in a fair fight, summoned back by the cult's ritual. Players must evade, hide, or break line of sight rather than fight.

Players log evidence via bodycam (aim and hold to "tag," mirroring real evidence documentation) toward revealing and reaching the ritual's anchor point. Runs follow a Lethal Company-style loop: the exit is always available, but leaving under the evidence quota ends the run as a narrative "failure" (case unresolved) and resets into another shift/dispatch call — with the implication the ritual has progressed regardless. Target run length is short: 10–20 minutes.

### Design Pillar: Asymmetric Horror, Symmetric World

The shared objective state (house layout at a macro level, evidence tally, ritual progress) is consistent for all players. Supernatural/ghost encounters, however, can be individually experienced — one player may see or hear something the others don't. This is both a horror-design choice (creates doubt and tension between friends: "you're seeing things") and a technical one (ghost encounters can be handled client-side rather than fully replicated, reducing netcode complexity for the hardest system to get right).

### Theme Interpretation: The Ritual Explains the Haunting

The ghosts are not random hauntings — they exist because the cult is actively calling them back. This gives the space's escalating wrongness a diegetic cause (the ritual, not an arbitrary curse) and ties the two threats together causally: stopping the cultists' ritual is what ultimately stops the ghosts and stabilizes the house.

### Primary Mechanics

| Mechanic | Description |
| --- | --- |
| Evidence Logging | Aim bodycam/flashlight at an item and hold to log it, mirroring real evidence-tagging. Feeds the run's evidence quota. Categories: ritual evidence, victim evidence, prior officer's bodycam/radio fragments. |
| Melee + Sidearm Combat | Grounded, desperate combat against cultists. No tactical lean/cover system — combat should feel risky and improvised, not precise. |
| Ghost Evasion | No means of fighting back against ghosts. Core verbs: break line of sight, hide, create distance. Individually experienced per player (see Design Pillar above). |
| Non-Euclidean Navigation | The house's layout is not fixed — hallways can loop, reconnect, or reveal new rooms as the ritual escalates. Initial implementation target: loop-based level design (a la P.T.) before attempting more advanced portal-based tricks. |
| Escalating Manifestation | The severity of the haunting (flicker frequency, house instability, ghost activity) increases with real time elapsed in a run, independent of player action — creates urgency without a literal on-screen timer. |

### Secondary Mechanics

| Mechanic | Description |
| --- | --- |
| Dispatch Radio (voice-only) | Unseen dispatcher acknowledges logged evidence and can deliver narrative beats — a diegetic substitute for a UI counter/quota tracker. |
| Loose Stealth | Cultists can be avoided, but detection is not punishing — players can fight their way out if spotted rather than needing a full stealth restart. |
| Prior Officer Fragments | Findable bodycam/radio clips from officers who responded before the player — narrative delivery mechanism tied to the found-footage framing device. |

---

## Art

### Visual Direction — Two Options Under Consideration

**Lighting quality is non-negotiable in either direction: both options use real-time dynamic shadows and bounce lighting, with flicker tied to specific triggers (proximity, sound, ritual escalation) rather than constant ambient noise. The difference between the two options is asset/model fidelity and overall production scope, not lighting quality.**

### Option A: PS2-Era Retro

Low-poly models, simple/limited textures, heavy directional fog and volumetric lighting shafts — a look proven commercially and critically by modern releases like Crow Country and Fear the Spotlight. Dramatically lower art production burden, well-suited to a small beginner team. Limited draw distance and fog become atmosphere generators rather than technical compromises, and can be diegetically justified as period-accurate CCTV/early bodycam hardware, reinforcing the found-footage framing instead of clashing with it. Effort saved on assets can go toward sound design, level logic, and gameplay feel.

### Option B: Photorealistic

Realistic environment art via Quixel Megascans, with Lumen lighting doing full physically-based work against high-fidelity materials. Higher ceiling if executed well, but requires character models, animation, and prop density to match the lighting/material quality or the mismatch becomes distracting. Meaningfully higher production cost and risk for a 3-person, largely-new team.

### Recommendation

Option A (PS2-era retro) is recommended given team size and experience level — it reduces the highest-risk production cost (art volume) while keeping the most important atmospheric tool (lighting) at full quality. Final decision pending team discussion.

---

## Audio

### Sound Design

Positional audio is treated as a primary horror tool, arguably more important than visuals — breathing, footsteps, radio static, distant chanting. Given the bodycam framing, audio should feel like it's being picked up by a body-worn mic: slightly muffled, prone to picking up the player's own movement/breathing prominently.

### Music

[TBD — revisit once a vertical slice exists to score against.]

---

## Game Experience

### UI

Minimal HUD, diegetic where possible — bodycam REC indicator, battery, timestamp double as functional UI elements (e.g., evidence-logged counter lives in the bodycam overlay, not a separate menu widget).

### Controls

[TBD once engine input mapping is set up — standard WASD + mouse for PC, aim-and-hold for evidence logging.]

---

## Development Timeline

### Milestone 1 — Core Wrongness Prototype

Single hallway-loop moment proving the "bigger on the inside" reveal is unsettling. No combat, no ghosts, no evidence system. Solo-testable.

### Milestone 2 — Co-op Foundation

2 players can occupy the same warping house together and both perceive the shared objective state correctly. This validates the hardest technical risk (networking) before more content is built on top of it.

### Milestone 3 — Threats

Cultist combat (melee + sidearm) and one ghost with individually-experienced evasion behavior.

### Milestone 4 — Evidence & Loop

Evidence logging system, dispatch radio acknowledgment, quota-based win/failure states, and the shift-reset loop.

### Milestone 5 — Procedural House Layouts

Move from hand-authored loop/mitosis layouts to procedurally generated house configurations, so no two runs use the same layout. Builds on the loop-based non-euclidean system from Milestone 1 — the same room/hallway pieces get assembled differently each run rather than existing as one fixed sequence. This is what gives the game long-term replayability.

### Milestone 6 — Content & Polish

Full room/hallway piece variety to feed the procedural system, remaining evidence/narrative content, audio pass, UI polish.
