# The House & Its Corruption

*Design decisions from team session, 2026-07-12. This document is the source
of truth for house generation and non-euclidean escalation. It extends
`docs/GDD.md` — where they conflict, this doc is newer and wins for house
systems specifically.*

---

## Core principle

**The house must make sense before it can stop making sense.**

The player's mental model of "a normal house" is the material the game is
built from. Every scare is a violation of that model, which means the model
must be established first. A maze is pre-violated — nothing in a maze can
feel wrong. A ranch house where the hallway back from the bedroom is one
door longer than it was: that is the game.

Corollary (from the GDD's own pitch): the interior is "far larger and
stranger *than the exterior suggests*" — the suggestion is a design
deliverable, not flavor.

---

## 1. The True House

The sane, canonical house that exists before corruption. First archetype:
**suburban ranch** (single story — no stair complexity, fastest to read,
easiest to generate). Later archetypes (backwoods colonial, etc.) are new
*generation profiles* over the same grammar, and the team can hand-design
them.

### Canonical ranch floor plan (v1)

Single story, ~16 m × 9 m footprint plus garage, basement under the kitchen
wing. Front door faces south (street side). Circulation follows the real
pattern: public zone at the front, service at the back, private wing down a
narrow hall.

```
                        BACK YARD (north)
  ┌─────────┬──────────┬─────┬──────────┬───────────────┐
  │ KITCHEN │  DINING  │ [B] │  BED 2   │  MASTER BED   │
  │ 3.6x3.6 │  3.0x3.6 │     │ 3.2x3.6  │   4.2x3.6     │
  │ (back   │ (opens to│stair│ (window  │ (ensuite half │
  │  door)  │  kitchen)│down │  north)  │  bath 1.6x2)  │
  ├───┬─────┴────┬─────┴─────┴──┬───────┴─┬─────────────┤
  │LDY│          HALLWAY  1.2 wide        │  HALL BATH  │
  │2x2│  (linen closet [C] mid-hall)      │   2.2x2.0   │
  ├───┴─────┬──────────────┬──────┬───────┴─┬───────────┤
  │ GARAGE  │  LIVING ROOM │FOYER │  BED 3  │ (side yard│
  │ 5.4x5.4 │   4.6x4.2    │2.0x  │ 3.0x3.6 │  window)  │
  │ [G]     │ (picture wdw)│ 2.4  │ (street │           │
  └─────────┴──────────────┴──┬───┴─────────┴───────────┘
                         FRONT DOOR (south)
                 porch → lawn → driveway → street
                      [police cruiser parked here]
```

Room-by-room notes:

| Room | Purpose & details | Corruption seam? |
| --- | --- | --- |
| Foyer | Coat hooks, small table, mirror. The anchor space. | Never corrupts (see §5) |
| Living | Couch, TV (static), picture window to street, family photos | TV is a Tier-1 device |
| Dining | Table + chairs (chair count is a Tier-1 dial), sideboard | — |
| Kitchen | Counters, fridge, table radio, back door, food out | Back door: seam |
| Hallway | 1.2 m wide, family photos, linen closet [C] | **Primary seam** |
| Linen closet [C] | Towels, sheets. The most boring door in the house. | **Set-piece graft point** |
| Bed 2 / Bed 3 | Kids' rooms — one tidy, one not | Interiors corrupt late |
| Master | Ensuite half-bath, closet | Closet: seam |
| Hall bath | Mirror, tub | Mirror is a Tier-1/2 device |
| Laundry [LDY] | Mud room between kitchen and garage | — |
| Garage [G] | Workbench, car? (car present = Tier-1 dial: engine warm) | Big seam (ritual space) |
| Basement [B] | Stairs down from kitchen wing. Unfinished. The cult's floor. | **The deep seam** |

Sightline rules (why this layout): from the foyer you can see into living
and down the hall — establishing shot. You can NEVER see the whole house
from anywhere. The hallway has exactly one bend. Windows only on exterior
walls, and every window's view must agree with the exterior the player
walked past.

### Generation architecture

- **Hand-built room modules, procedurally assembled.** Team members build
  room variant scenes in the Godot editor (three living rooms, four
  bedrooms...) with marked **door sockets**; the generator assembles them
  per the grammar below. This is the Lethal Company model: handcrafted
  chunks, procedural layout. (Team workflow win: room-building is ideal
  beginner editor work, no code required.)
- **Grammar (ranch profile):** foyer on street side → living adjacent foyer
  → dining adjacent living AND kitchen → kitchen at back with back door →
  hall connects public zone to private wing → 2–3 bedrooms + bath off hall,
  bath adjacent bedrooms → laundry between kitchen and garage → basement
  stairs off kitchen or hall. Rooms 3–5 m; halls 1.2 m; ceilings 2.5 m.
- **v1 shortcut:** until the module library exists, the generator builds
  the canonical plan above directly (fixed layout, randomized furnishing/
  details). Randomized *layouts* come with the module library.
- A sane ranch is 10–12 rooms — deliberately too small for a 15-minute run.
  **The play space comes from corruption** (§3): the house grows during the
  run. The true house is the tutorial; the additions are the game.

---

## 2. The run starts outside

Every shift begins on the street: police cruiser at the curb, light bar
strobing red/blue across the lawn and the front of the house. The player
walks the approach — lawn, porch, front door. Purpose:

1. Establishes the exterior the interior will later betray (footprint,
   window count, one story).
2. The cruiser's red/blue wash is a signature lighting beat — and the
   radio in the car is the dispatch anchor.
3. The approach is the calm baseline the whole horror curve is measured
   against.

From the very first shift the approach is *lightly* off — same register as
the interior start: a porch light flickering, faint TV static glow in one
window, a barely-audible high tinnitus that fades in near the house.
Largely normal. Small things.

## 2b. The haunting reaches the outside (across shifts)

*(Idea logged 2026-07-12 — pairs with the Lethal Company-style multi-day
quota loop, see gameplay-loop doc when written.)*

The run loop gives you several shifts/days against a quota. **Each
consecutive shift, the haunting has leaked further outside the house.** The
exterior escalates across days the way the interior escalates within a run:

- **Day 1:** As above — porch flicker, one window glowing static, light
  tinnitus. Deniable.
- **Day 2:** Streetlights die as you pass under them. Every neighbor window
  dark. No birds, no crickets. The cruiser radio spits static when facing
  the house. The lawn is dead in a rough circle around the porch.
- **Day 3:** Fog on an empty street. The house is subtly wrong from
  outside — one window too many, proportions a little too long (the
  exterior itself begins to lie). Sky starless. The tinnitus starts at the
  curb.
- **Later days (if the loop allows):** the street no longer fully agrees
  with itself — design space reserved.

The message: the ritual isn't contained, and your failure to close the case
has a visible cost. The world outside the car door is the scoreboard.

---

## 3. Corruption: WHERE

**The connections lie before the rooms do.** Corruption lives first at
seams — doors, the hallway, closets, the basement stairs — because behind a
door is where the house can cheat invisibly. Room interiors stay stubbornly
domestic long after the topology stops adding up: a perfectly normal
bedroom reached by an impossible route beats a weird bedroom every time.
Interior wrongness (furniture on the ceiling, the chair room) is a
late-run privilege.

Seam inventory (v1): linen closet, master closet, basement door, garage
door, hallway far end, back door. Grafts happen there: a closet that opens
into a second, identical hallway; a basement with too many flights; a new
door at the end of the hall that was not there when you walked in.

## 4. Corruption: WHEN — the deniability curve

Wrongness is tiered; tiers unlock with ritual escalation (time-driven,
spiked by evidence tagging, per the existing HauntDirector). The curve runs
from deniable to undeniable — early wrongness must leave room for the
player to doubt themselves.

- **Tier 0 — Off (from minute zero):** ambient only. Too many chairs at
  the dinner table. Every clock stopped at the same time. Food still warm,
  tap running, TV on static. Lights flicker. Faint tinnitus. Nothing you
  could put in a report. *(Flavor: grounded "crime scene that hasn't
  happened yet" + AV interference. Quietly-impossible details — e.g.,
  family photos of empty rooms — are rationed and appear a tier late.)*
- **Tier 1 — Deniable:** topology lies where you can't be sure. A door you
  don't remember. The hallway back feels one door longer. Changes happen
  ONLY off-screen — behind you, behind closed doors. The player argues
  with themselves. Highest-value tier in the game; spend it slowly.
- **Tier 2 — Undeniable, contained:** set-pieces (§6). The loop hallway.
  The door-roulette room. The house cheats openly but inside a trap with
  entry and exit rules.
- **Tier 3 — Collapse:** pocket realms, rooms that stop pretending, the
  deep house, ceiling furniture, the chair room. Late run only.

Rule of thumb: a change the player *watches happen* costs a full tier more
than the same change discovered after the fact. On-screen mutation is
end-of-run material.

## 5. The front door never lies

No matter what the house does, the route from the player's position back
along their original path to the front door stays honest. Corruption grows
outward and deeper — never between the player and out. This implements the
GDD's "always can leave" pillar spatially, gives players one trustworthy
anchor, and makes everything beyond it scarier by contrast. (In co-op,
this rule is per-house, not per-player — the shared exit is part of the
symmetric world.)

## 6. The set-piece deck

Handcrafted scares, procedurally deployed. The HauntDirector grafts one
onto a seam, targets ONE player (asymmetric horror — the others hear about
it), and removes it after. Current deck:

1. **The Long Hall** (built): corridor loops until it decides you're done;
   admits one occupant; exits somewhere else.
2. **Door roulette** (designed): a room whose exits only exist where you
   aren't looking. Doors appear on walls as you look away; each wrong door
   re-enters the same room; one releases you. Uses the ghost's gaze-
   detection tech.
3. **The chair room** (built): chair, lamp, wrong number of shadows.
4. **Pocket realms** (built): forest with the house's floor, night field,
   moonless beach. Tier 3 only, rationed — these are the deep end.

Deck grows over time; every set-piece defines: entry seam, occupancy rule,
release rule, and what the other players perceive meanwhile.

---

## Open questions (next design sessions)

- Gameplay loop specifics: shifts-to-quota, what evidence unlocks (anchor
  point reveal?), what persists between shifts. → needs its own doc.
- Threat interaction model (cultists with jobs, ghost-through-environment,
  chanting as radar). → needs its own doc.
- Story: who the ghosts are, what dispatch knows, what the anchor point
  physically is.
- Second archetype (backwoods colonial: two floors, no neighbors, longer
  approach) — after the ranch works.
