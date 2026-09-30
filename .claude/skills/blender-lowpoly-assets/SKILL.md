---
name: blender-lowpoly-assets
description: Generate clean low-poly 3D game assets (spaceships, stations, turrets, props) with headless Blender and export them as Godot-ready .glb files with named hardpoints, engine markers, LODs and a FACTION tint material, then validate them against the Deathworlders asset contract and render preview images. Use this skill whenever the user wants a 3D model, ship, hull, station, turret, weapon mount, prop or .glb made for Godot or for the Deathworlders game, asks to "generate/make/model/build" any game asset in Blender, needs hardpoints or LODs, or wants existing .glb files checked against the asset rules, even if they don't mention Blender explicitly.
---

# Blender Low-Poly Assets

Build game assets from a **JSON spec** with headless Blender, export **.glb** that follows the asset contract, validate it, and look at preview renders before handing it over. The JSON-spec approach matters: it keeps assets reproducible (same spec = same model), diffable in git, and easy to tweak one number at a time.

## Files in this skill

| Path | What it is | When to read/use |
|---|---|---|
| `scripts/build_asset.py` | Blender script: spec → .glb + sidecar + previews | Every build |
| `scripts/validate_glb.py` | Pure-Python contract validator (no Blender) | After every build, and on any .glb the user gives you |
| `scripts/build_all.sh` | Build + validate every spec in a folder | Batch work |
| `references/asset_contract.md` | The rules every asset must follow (axes, units, naming, budgets) | Read before the first build in a session |
| `references/spec_format.md` | Full JSON spec reference with all section types and fields | When writing or editing a spec |
| `references/species_styles.md` | Visual language per species/faction | When designing a new ship or station |
| `assets/examples/*.json` | Working specs: human corvette, human cruiser, Vess'kar corvette, railgun turret | Start new specs by copying the closest example |

## Workflow

1. **Find Blender.** Check `$BLENDER_PATH`, then `blender` on PATH, then common install locations (Windows: `C:\Program Files\Blender Foundation\Blender <ver>\blender.exe`; macOS: `/Applications/Blender.app/Contents/MacOS/Blender`; Linux: `/usr/bin/blender`, `~/blender-*/blender`). Confirm with `blender --version`. Blender 4.2+ should work; tested on Blender 5.2.2 LTS with imports verified in Godot 4.7.2.
2. **Read the contract** (`references/asset_contract.md`) if you haven't this session.
3. **Write the spec.** Copy the closest example from `assets/examples/`, then adjust. Put project specs in the repo at `tools/blender/specs/<id>.json` (not inside the skill) so they're versioned with the game.
   - Match hardpoints to the hull's slot layout in the game data (e.g. Sub-spec A2: Cruiser Mk I = 1S 2M weapons, 2D, 1U, 1C). The validator's `--expect` flag checks this.
   - Keep the ship pointing along **Blender +Y** and engines at **−Y**.
4. **Build with previews:**
   ```bash
   blender -b --factory-startup --python <skill>/scripts/build_asset.py -- \
     --spec tools/blender/specs/human_cruiser_mk1.json --out assets/models/ships --preview
   ```
   Look for `BUILD_OK` and the JSON report in stdout. EGL warnings in headless mode are harmless.
5. **Validate:**
   ```bash
   python3 <skill>/scripts/validate_glb.py assets/models/ships/human_cruiser_mk1.glb \
     --expect HP_W_M_01,HP_W_M_02,HP_W_S_01,HP_D_M_01,HP_D_M_02,HP_U_S_01,HP_C_M_01
   ```
   Fix every ERROR. Warnings are judgement calls; mention them to the user.
6. **Look at the previews** (`<id>_front.png`, `<id>_rear.png`) with the image viewer before reporting. Check silhouette, species style, engines at the back, and whether it reads clearly at small size. Iterate on the spec if something looks off; don't hand over an asset you haven't looked at.
7. **Report briefly:** file paths, triangle counts per LOD vs budget, hardpoint list, dimensions in metres, and any warnings. Keep preview images out of the game's `assets/` folder (put them in `tools/blender/previews/` or delete them).

## Design guidance

- **Silhouette first.** At strategy-game zoom levels, players identify ships by outline. Give each class a distinct profile (a corvette is a dart, a cruiser a slab with a superstructure, a carrier a flat deck, a battleship a fortress).
- **Detail levels** do the LOD work: `detail: 0` parts appear in all LODs, `1` in LOD0–1, `2` (greebles) only in LOD0. Put small parts at 1 or 2 so LOD2 stays a clean silhouette.
- **FACTION panels** should be large, readable surfaces (side armour, wings), because they carry the empire colour on the map.
- **Budgets are ceilings, not targets.** A corvette at 400 tris that reads well beats one at 800 with noise.
- **Bevels** only on big sections (small bevels on tiny parts waste triangles).
- **Turrets** are separate assets (`kind: "turret"`) whose base sits at the origin, barrels pointing +Y. The game attaches them to hardpoints, so hulls should not include turret geometry at weapon hardpoints.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Validator: "engines are in front of centre" | Ship built facing −Y; flip Y positions in the spec |
| Hardpoint numbering unexpected | Numbering is per slot+size in spec order; mirrored hardpoints get the next number |
| Triangle budget exceeded | Lower greeble count, reduce cylinder `segments`, remove bevels on small parts |
| Preview is empty/black | Check `dimensions_units` in the report; a section may be positioned far from origin |
| `Principled BSDF` input errors | Newer Blender renamed inputs; the script already tries both names. Report the Blender version if it still fails |
