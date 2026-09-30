# Spec Format

A spec is one JSON object. Coordinates are Blender space: **X = right, Y = forward, Z = up**, in units (1 = 10 m).

## Top level

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | File name and root node name, e.g. `human_cruiser_mk1` |
| `kind` | `ship` \| `station` \| `turret` \| `prop` | no (ship) | |
| `class` | string | recommended | Used for triangle budget (see asset_contract.md) |
| `style` | `human` \| `vesskar` \| `krothi` \| `ohlan` \| `thessari` \| `neutral` | no (neutral) | Sets HULL/DARK/EMISSIVE colours |
| `lods` | int 1–3 | no (3) | Turrets usually 2 |
| `sections` | array | yes | Geometry pieces (below) |
| `engines` | array | no | Adds DARK bell + EMISSIVE glow + `ENGINE_NN` marker |
| `hardpoints` | array | no | Adds `HP_*` empties |
| `markers` | object | no | `BRIDGE`, `DOCK`: [x,y,z]; `LIGHT`: [x,y,z] or list of them |
| `greebles` | object | no | Deterministic small detail boxes, LOD0 only |

## Section fields (all types)

| Field | Notes |
|---|---|
| `type` | `box`, `wedge`, `cylinder`, `sphere` |
| `pos` | [x,y,z] centre |
| `rot` | [x,y,z] degrees, applied X then Y then Z |
| `mat` | `HULL` (default), `DARK`, `FACTION`, `EMISSIVE` |
| `mirror_x` | true → also builds a copy mirrored across X |
| `detail` | 0 all LODs (default), 1 LOD0–1, 2 LOD0 only |
| `bevel` | bevel width (box/wedge only, LOD0 only). Use ~2–5% of the section's smallest size |

### `box`
`size`: [width X, length Y, height Z]. Optional `taper_front` / `taper_back`: [scaleX, scaleZ] applied to the +Y / −Y face. `shift_front_z`: raise/lower the front face.

### `wedge`
A box with default `taper_front: [0.05, 0.3]`: a prow or nose. Override `taper_front` to shape it.

### `cylinder`
`radius`, `length`, optional `radius_end` (cone), `segments` (6 = hex, low-poly default), `axis`: `y` (default, along the ship), `z` (vertical, e.g. turret base), `x`.

### `sphere`
`radius`, `subdivisions` (1–2), `scale`: [x,y,z] to stretch into hulls and pods. Good for organic/elegant species.

## Engines
```json
{"pos": [x, y, z], "radius": 0.5, "segments": 6, "mirror_x": true}
```
Put `pos` at the rear face of the hull; the bell extends slightly back.

## Hardpoints
```json
{"slot": "W", "size": "M", "pos": [x, y, z], "dir": "up", "mirror_x": false}
```
`dir`: `up`, `down`, `left`, `right`, `forward`, `back` (mirrored left/right swap automatically). Numbering is per (slot, size) in spec order: first `W M` → `HP_W_M_01`.

## Greebles
```json
{"seed": 7, "count": 10, "area": [xmin, xmax, ymin, ymax, z], "min": 0.1, "max": 0.3, "mirror_x": true}
```
Place `area` on a flat top surface (`z` = that surface's height). Same seed = same greebles.
