# Handoff from the planning session (claude.ai, 30 Sep 2026)

Read this first, then CLAUDE.md and the spec named in the task.

## Where we are
- Planning is complete: main spec v1.2 + Sub-specs A–F + M1 plan are in docs/.
- Pre-flight is mostly done: GUT 9.7.0 installed and passing, CLAUDE.md written, RNG/hash reference
  vectors in tools/reference/, Blender skill in .claude/skills/blender-lowpoly-assets, four sample
  models in assets/models/ (verified importing into Godot 4.7.2).
- Remaining pre-flight on this PC: install Godot 4.7.2 + Blender 5.2.2, git init, Godot MCP.
- **Next task: M1 WP1 (project skeleton), then WP2 (deterministic foundations).**

## Key decisions (the "why" behind the specs)
- Deterministic lockstep multiplayer from day one: integer-only sim, seeded RNG streams,
  commands as the only way to change state. Retrofitting this later is too expensive.
- Resources are physical and local (except credits, research, influence): logistics is the core game.
- Automation first (sectors, governors, templates, alerts) so large empires stay manageable;
  the AI uses the same automation.
- Battles auto-resolve; player skill is intel, loadouts (fixed slots, refits) and doctrine.
- Fog of war is a per-empire knowledge model inside the sim (deterministic; AI plays fair).
- Full mod support: string IDs, layered Def database, base game ships as the "core" mod,
  species signature mechanics implemented as core ModScripts.
- Visual style: "Control Room" — white room, greyscale ink, glass panels, red only for FLASH
  alerts. The game is presented as a Fleet Command OS with three instruments:
  strategic plot (galaxy), operational plot (cluster), tactical scope (solar, 3D white room).
  Allegiance shown by military-style frame shapes (APP-6 inspired). See SUBSPEC_F_UI.md F21–F22
  and docs/mockups/control_room.html.

## Known open tuning items
- Combat prototype: numbers overpower counters (Sub-spec A14). Fix via morale/retreat and screening.
- Economy: early components may be too tight (Sub-spec B21).
