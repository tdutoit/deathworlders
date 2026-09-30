# Deathworlders

HFY 4X space strategy game for Godot 4. Design docs in `docs/`, project rules for Claude Code in `CLAUDE.md`.

## Pre-flight checklist (M1 Plan D0): complete

- [x] D0.1 Godot 4.7.2-stable (standard build). Set `GODOT` to the console exe for `tools/run_tests.sh`.
- [x] D0.2 Git repository initialised
- [x] D0.3 Specs copied into `docs/`
- [x] D0.4 Godot MCP: `godot-mcp` Claude Code plugin (signalcompose) + editor addon in `addons/godot_mcp`
      (enabled in `project.godot`; locally patched to listen on 127.0.0.1 only). Open the project in the
      Godot editor, then check with `/mcp` or `/godot-mcp:status`.
- [x] D0.5 Blender 5.2.2 LTS + `blender-lowpoly-assets` skill (`.claude/skills/`). Set `BLENDER_PATH`.
      No system Python needed: run `validate_glb.py` with Blender's bundled `5.2/python/bin/python.exe`.
- [x] D0.6 GUT 9.7.0 in `addons/gut`, placeholder test passes headless (`tools/run_tests.sh`)
- [x] D0.7 `CLAUDE.md` written
- [x] Deterministic RNG/hash reference + test vectors (`tools/reference/`), ahead of WP2
- [x] Sample assets: human corvette & cruiser, Vess'kar corvette, railgun turret (`assets/models/`), verified in Godot 4.7.2

Next: **M1 WP1** (docs/M1_PLAN.md).
