# Asset Contract (Deathworlders, Sub-spec C11)

Every generated asset must follow these rules. `scripts/validate_glb.py` checks the ones marked ✔.

| Rule | Value | Checked |
|---|---|---|
| Format | glTF 2.0 binary (`.glb`) | ✔ |
| Units | 1 Blender unit = 1 Godot unit = **10 m** | (report shows metres) |
| Forward | Ships face **Blender +Y** → exported as **Godot −Z** | ✔ (engine position check) |
| Up | Blender +Z → Godot +Y (exporter Y-up on) | |
| Origin | Centre of mass at origin; ships sit on origin | |
| Root | Exactly **one root node**, named `<id>` | ✔ |
| Meshes | `<id>_LOD0`, `<id>_LOD1`, `<id>_LOD2` children of root | ✔ LOD0 required; LODs must not increase tris |
| Hardpoints | Empties named `HP_<W|D|U|C|H>_<S|M|L>_<NN>` (W weapon, D defence, U utility, C core, H hangar) | ✔ naming, ✔ `--expect` list |
| Hardpoint orientation | Empty's +Z (Blender) = mount "up" = direction the turret faces away from the hull | |
| Markers | `ENGINE_NN` (thrust FX, pointing back), `BRIDGE`, `DOCK`, `LIGHT_NN` | ✔ naming (warning) |
| Materials | `HULL`, `DARK`, `FACTION` (tinted at runtime), `EMISSIVE` | ✔ FACTION present (warning) |
| Shading | Flat (no smooth shading), no textures required | |
| Naming | Hulls `<species>_<class>_mk<N>.glb`; turrets `<component_id>.glb` | |

## Triangle budgets (LOD0)

| Class | Budget | | Class | Budget |
|---|---|---|---|---|
| scout | 600 | | battlecruiser | 3,500 |
| corvette | 800 | | battleship | 6,000 |
| frigate | 1,200 | | carrier | 5,000 |
| destroyer | 1,600 | | station | 5,000 |
| cruiser | 2,500 | | turret | 400 |
| freighter | 1,200 | | transport | 1,000 |
| prop | 1,500 | | | |

LOD1 should land around 40–60% of LOD0, LOD2 around 15–30%.

## Suggested lengths (Blender units; ×10 = metres)

| Class | Length | | Class | Length |
|---|---|---|---|---|
| scout | 4 | | battlecruiser | 28 |
| corvette | 6–7 | | battleship | 45–60 |
| frigate | 9 | | carrier | 40–50 |
| destroyer | 12 | | freighter (light) | 8 |
| cruiser | 20 | | station T1 | 30–40 |

## Sidecar `<id>.asset.json`

Written next to every .glb: id, kind, class, style, triangle counts per LOD, hardpoint names, marker names, dimensions (units and metres). The game's content validator can read it; HullDef authors use it to fill slot hardpoints.

## In Godot (verified with Godot 4.7.2)

- The imported scene gets a wrapper root named after the file; the `<id>` Node3D is its first child, with `HP_*`, `ENGINE_*`, markers and `<id>_LODn` MeshInstance3D nodes beneath it.
- Forward is −Z (e.g. a bow hardpoint at Blender y=+1.3 imports at z=−1.3); engines sit at +Z.
- A hardpoint's `basis.y` is its mount direction (`dir: "down"` imports as basis.y = (0, −1, 0)).
- Surfaces keep their material names (`HULL`, `DARK`, `FACTION`, `EMISSIVE`), so game code can find the `FACTION` surface by `resource_name` and apply the empire tint.
- LOD meshes import as separate MeshInstance3D nodes; the game toggles their visibility (or uses `visibility_range_*`).
