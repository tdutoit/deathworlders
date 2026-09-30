#!/usr/bin/env python3
"""
Validate a .glb against the Deathworlders asset contract (references/asset_contract.md).
Pure Python (no Blender). Usable by the skill, CI, and the Godot content validator.

Usage:
  python3 validate_glb.py model.glb [--class corvette] [--expect HP_W_S_01,HP_W_S_02] [--json]

Exit code 0 = pass (warnings allowed), 1 = contract errors.
"""
import json, re, struct, sys

BUDGETS = {  # LOD0 triangle budgets
    "corvette": 800, "frigate": 1200, "destroyer": 1600, "cruiser": 2500, "battlecruiser": 3500,
    "battleship": 6000, "carrier": 5000, "freighter": 1200, "transport": 1000, "scout": 600,
    "station": 5000, "turret": 400, "prop": 1500,
}
HP_RE = re.compile(r"^HP_[WDUCH]_[SML]_\d{2}$")
MARKER_RE = re.compile(r"^(ENGINE_\d{2}|LIGHT_\d{2}|BRIDGE|DOCK)$")
LOD_RE = re.compile(r"^(.+)_LOD(\d)$")

def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("not a GLB file")
    clen, ctype = struct.unpack_from("<I4s", data, 12)
    if ctype != b"JSON":
        raise ValueError("first chunk is not JSON")
    return json.loads(data[20:20 + clen]), version

def tri_count(gltf, mesh):
    n = 0
    for prim in mesh["primitives"]:
        mode = prim.get("mode", 4)
        if mode != 4:
            continue
        if "indices" in prim:
            n += gltf["accessors"][prim["indices"]]["count"] // 3
        else:
            n += gltf["accessors"][prim["attributes"]["POSITION"]]["count"] // 3
    return n

def mesh_bounds(gltf, mesh):
    lo = [1e9] * 3; hi = [-1e9] * 3
    for prim in mesh["primitives"]:
        acc = gltf["accessors"][prim["attributes"]["POSITION"]]
        for i in range(3):
            lo[i] = min(lo[i], acc["min"][i]); hi[i] = max(hi[i], acc["max"][i])
    return lo, hi

def validate(path, asset_class=None, expect=None):
    errors, warnings = [], []
    gltf, version = read_glb(path)
    nodes = gltf.get("nodes", [])
    names = [n.get("name", "") for n in nodes]
    scene = gltf["scenes"][gltf.get("scene", 0)]
    roots = scene.get("nodes", [])

    if len(roots) != 1:
        errors.append(f"expected exactly 1 root node, found {len(roots)}")
    root_name = nodes[roots[0]].get("name", "") if roots else ""

    # LOD meshes
    lods = {}
    for n in nodes:
        m = LOD_RE.match(n.get("name", ""))
        if m and "mesh" in n:
            lods[int(m.group(2))] = n
    if 0 not in lods:
        errors.append("missing <id>_LOD0 mesh node")
    tris = {f"LOD{k}": tri_count(gltf, gltf["meshes"][v["mesh"]]) for k, v in sorted(lods.items())}
    for k in range(1, len(lods)):
        a, b = tris.get(f"LOD{k-1}"), tris.get(f"LOD{k}")
        if a is not None and b is not None and b > a:
            warnings.append(f"LOD{k} ({b} tris) has more triangles than LOD{k-1} ({a})")

    # budget: explicit --class, else sidecar <id>.asset.json, else guess from name
    if not asset_class:
        import os
        side = os.path.splitext(path)[0] + ".asset.json"
        if os.path.exists(side):
            with open(side) as f:
                asset_class = json.load(f).get("class")
    cls = asset_class or next((c for c in BUDGETS if f"_{c}" in root_name), None)
    if cls and "LOD0" in tris:
        if tris["LOD0"] > BUDGETS[cls]:
            errors.append(f"LOD0 has {tris['LOD0']} tris, budget for {cls} is {BUDGETS[cls]}")
    elif not cls:
        warnings.append("asset class unknown; triangle budget not checked (pass --class)")

    # materials
    mat_names = [m.get("name", "") for m in gltf.get("materials", [])]
    if "FACTION" not in mat_names and cls not in ("prop",):
        warnings.append("no FACTION material slot (runtime tint will not apply)")

    # hardpoints & markers
    hps = [n for n in names if n.startswith("HP_")]
    bad_hp = [n for n in hps if not HP_RE.match(n)]
    for n in bad_hp:
        errors.append(f"bad hardpoint name: {n}")
    others = [n for n in names if n and n != root_name and not n.startswith("HP_") and not LOD_RE.match(n)]
    for n in others:
        if not MARKER_RE.match(n):
            warnings.append(f"unrecognised node name: {n}")
    if expect:
        missing = [e for e in expect if e not in hps]
        for e in missing:
            errors.append(f"expected hardpoint missing: {e}")

    # orientation: engines should sit behind centre (glTF +Z is backward when forward is -Z)
    dims = None
    if 0 in lods:
        lo, hi = mesh_bounds(gltf, gltf["meshes"][lods[0]["mesh"]])
        dims = {"x": round(hi[0] - lo[0], 3), "y": round(hi[1] - lo[1], 3), "z": round(hi[2] - lo[2], 3)}
        cz = (lo[2] + hi[2]) / 2
        eng_z = [nodes[i].get("translation", [0, 0, 0])[2] for i, n in enumerate(names) if n.startswith("ENGINE_")]
        if eng_z and sum(eng_z) / len(eng_z) < cz:
            errors.append("engines are in front of centre: model faces +Z; forward must be -Z (Blender +Y)")
        if cls not in ("station", "turret", "prop") and dims["z"] < dims["x"] * 0.8:
            warnings.append("model is wider than long; check forward axis")

    return {
        "file": path, "gltf_version": version, "root": root_name, "class": cls,
        "triangles": tris, "dimensions_units": dims, "hardpoints": sorted(hps),
        "markers": sorted(n for n in others if MARKER_RE.match(n)), "materials": mat_names,
        "errors": errors, "warnings": warnings, "ok": not errors,
    }

if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    path = args[0]
    cls = args[args.index("--class") + 1] if "--class" in args else None
    exp = args[args.index("--expect") + 1].split(",") if "--expect" in args else None
    res = validate(path, cls, exp)
    if "--json" in args:
        print(json.dumps(res, indent=2))
    else:
        print(f"{'PASS' if res['ok'] else 'FAIL'}  {path}")
        print(f"  root={res['root']} class={res['class']} tris={res['triangles']} dims={res['dimensions_units']}")
        print(f"  hardpoints={res['hardpoints']}")
        print(f"  markers={res['markers']}")
        for e in res["errors"]:
            print(f"  ERROR: {e}")
        for w in res["warnings"]:
            print(f"  warn:  {w}")
    sys.exit(0 if res["ok"] else 1)
