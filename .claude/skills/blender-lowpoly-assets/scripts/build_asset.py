"""
Build a low-poly game asset (ship, station, turret, prop) from a JSON spec, headless.

Usage:
  blender -b --factory-startup --python build_asset.py -- --spec path/to/spec.json --out out_dir [--preview]

Produces in out_dir:
  <id>.glb           glTF binary following the asset contract (references/asset_contract.md)
  <id>.asset.json    sidecar: dimensions, triangle counts per LOD, hardpoints, markers
  <id>_front.png, <id>_rear.png   (with --preview) orthographic 3/4 preview renders

Coordinate convention (Blender side):
  Ships point FORWARD along Blender +Y  (=> Godot -Z after the exporter's Y-up conversion)
  Up is Blender +Z                      (=> Godot +Y)
  1 Blender unit = 1 Godot unit = 10 m
"""
import bpy, bmesh, json, math, os, sys, random
from mathutils import Matrix, Vector

# ---------------------------------------------------------------- args
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default
SPEC_PATH = arg("--spec")
OUT_DIR = arg("--out", ".")
PREVIEW = "--preview" in argv
if not SPEC_PATH:
    raise SystemExit("--spec is required")
with open(SPEC_PATH) as f:
    SPEC = json.load(f)
os.makedirs(OUT_DIR, exist_ok=True)

# ---------------------------------------------------------------- style palettes
STYLES = {
    # base colours (linear-ish RGBA) for HULL, DARK, FACTION (neutral grey, tinted at runtime), EMISSIVE
    "human":    {"HULL": (0.42, 0.44, 0.46, 1), "DARK": (0.12, 0.13, 0.14, 1), "EMISSIVE": (1.0, 0.55, 0.15, 1)},
    "vesskar":  {"HULL": (0.80, 0.82, 0.86, 1), "DARK": (0.30, 0.33, 0.40, 1), "EMISSIVE": (0.45, 0.75, 1.0, 1)},
    "krothi":   {"HULL": (0.35, 0.25, 0.18, 1), "DARK": (0.15, 0.08, 0.06, 1), "EMISSIVE": (0.9, 0.9, 0.2, 1)},
    "ohlan":    {"HULL": (0.55, 0.47, 0.30, 1), "DARK": (0.20, 0.18, 0.14, 1), "EMISSIVE": (0.3, 1.0, 0.6, 1)},
    "thessari": {"HULL": (0.62, 0.70, 0.62, 1), "DARK": (0.22, 0.28, 0.25, 1), "EMISSIVE": (0.7, 0.5, 1.0, 1)},
    "neutral":  {"HULL": (0.5, 0.5, 0.5, 1),    "DARK": (0.15, 0.15, 0.15, 1), "EMISSIVE": (1, 1, 1, 1)},
}
MAT_ORDER = ["HULL", "DARK", "FACTION", "EMISSIVE"]

# ---------------------------------------------------------------- scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)

def make_material(name, rgba, emissive=False):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba                      # used by Workbench preview
    if hasattr(mat, "use_nodes"):
        try:
            mat.use_nodes = True                  # no-op / deprecated in newer Blender
        except Exception:
            pass
    nt = mat.node_tree
    if nt:
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = rgba
            bsdf.inputs["Roughness"].default_value = 0.7
            if emissive:
                for key in ("Emission Color", "Emission"):
                    if key in bsdf.inputs:
                        bsdf.inputs[key].default_value = rgba
                if "Emission Strength" in bsdf.inputs:
                    bsdf.inputs["Emission Strength"].default_value = 3.0
    return mat

style = STYLES.get(SPEC.get("style", "neutral"), STYLES["neutral"])
MATS = {
    "HULL": make_material("HULL", style["HULL"]),
    "DARK": make_material("DARK", style["DARK"]),
    "FACTION": make_material("FACTION", (0.85, 0.85, 0.85, 1)),   # tinted at runtime in Godot
    "EMISSIVE": make_material("EMISSIVE", style["EMISSIVE"], emissive=True),
}

# ---------------------------------------------------------------- primitive builders (all into one bmesh per LOD)
def _finish(bm, verts, mat_name, pos, rot_deg):
    """Rotate + translate the new verts, assign material to their faces."""
    rot = Matrix.Rotation(math.radians(rot_deg[0]), 4, "X") @ \
          Matrix.Rotation(math.radians(rot_deg[1]), 4, "Y") @ \
          Matrix.Rotation(math.radians(rot_deg[2]), 4, "Z")
    M = Matrix.Translation(Vector(pos)) @ rot
    bmesh.ops.transform(bm, matrix=M, verts=verts)
    vset = set(verts)
    idx = MAT_ORDER.index(mat_name)
    faces = [f for f in bm.faces if all(v in vset for v in f.verts)]
    for f in faces:
        f.material_index = idx
        f.smooth = False
    return faces

def add_box(bm, sec, bevel):
    sx, sy, sz = sec["size"]                        # width (X), length (Y), height (Z)
    res = bmesh.ops.create_cube(bm, size=1.0)
    verts = res["verts"]
    tf = sec.get("taper_front", [1.0, 1.0])         # scale X,Z of the +Y end
    tb = sec.get("taper_back", [1.0, 1.0])          # scale X,Z of the -Y end
    for v in verts:
        t = tf if v.co.y > 0 else tb
        v.co.x *= sx * t[0]
        v.co.z *= sz * t[1]
        v.co.y *= sy
        if v.co.y > 0 and "shift_front_z" in sec:
            v.co.z += sec["shift_front_z"]
    faces = _finish(bm, verts, sec.get("mat", "HULL"), sec.get("pos", [0, 0, 0]), sec.get("rot", [0, 0, 0]))
    if bevel and sec.get("bevel", 0) > 0:
        edges = list({e for f in faces for e in f.edges})
        bmesh.ops.bevel(bm, geom=edges, offset=sec["bevel"], segments=1, affect="EDGES", profile=0.5)
    return verts

def add_cylinder(bm, sec, bevel):
    r = sec["radius"]; ln = sec["length"]
    r2 = sec.get("radius_end", r)
    seg = sec.get("segments", 6)
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                                radius1=r, radius2=r2, depth=ln)
    verts = res["verts"]
    # create_cone builds along Z; lay it along Y (forward) unless axis == "z"
    if sec.get("axis", "y") == "y":
        bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"))
    elif sec.get("axis") == "x":
        bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"))
    _finish(bm, verts, sec.get("mat", "HULL"), sec.get("pos", [0, 0, 0]), sec.get("rot", [0, 0, 0]))
    return verts

def add_wedge(bm, sec, bevel):
    """A box whose front collapses to a line (nose / prow)."""
    sec = dict(sec)
    sec["taper_front"] = sec.get("taper_front", [0.05, 0.3])
    return add_box(bm, sec, bevel)

def add_sphere(bm, sec, bevel):
    res = bmesh.ops.create_icosphere(bm, subdivisions=sec.get("subdivisions", 1), radius=sec["radius"])
    verts = res["verts"]
    sc = sec.get("scale", [1, 1, 1])
    for v in verts:
        v.co.x *= sc[0]; v.co.y *= sc[1]; v.co.z *= sc[2]
    _finish(bm, verts, sec.get("mat", "HULL"), sec.get("pos", [0, 0, 0]), sec.get("rot", [0, 0, 0]))
    return verts

BUILDERS = {"box": add_box, "cylinder": add_cylinder, "wedge": add_wedge, "sphere": add_sphere}

def mirrored(sec):
    s = json.loads(json.dumps(sec))
    p = s.get("pos", [0, 0, 0]); s["pos"] = [-p[0], p[1], p[2]]
    r = s.get("rot", [0, 0, 0]); s["rot"] = [r[0], -r[1], -r[2]]
    return s

def expand_sections():
    out = []
    for sec in SPEC.get("sections", []):
        out.append(sec)
        if sec.get("mirror_x"):
            out.append(mirrored(sec))
    # engines -> emissive nozzles + DARK bells
    for eng in SPEC.get("engines", []):
        p = eng["pos"]; r = eng["radius"]
        bell = {"type": "cylinder", "radius": r, "radius_end": r * 0.8, "length": r * 1.2,
                "segments": eng.get("segments", 6), "mat": "DARK", "pos": p, "detail": 0}
        glow = {"type": "cylinder", "radius": r * 0.7, "length": r * 0.2, "segments": eng.get("segments", 6),
                "mat": "EMISSIVE", "pos": [p[0], p[1] - r * 0.6, p[2]], "detail": 1}
        out += [bell, glow]
        if eng.get("mirror_x"):
            out += [mirrored(bell), mirrored(glow)]
    # deterministic greebles (LOD0 only)
    g = SPEC.get("greebles")
    if g:
        rng = random.Random(g.get("seed", 1))
        for _ in range(g.get("count", 0)):
            area = g["area"]  # [xmin,xmax,ymin,ymax,z]
            x = rng.uniform(area[0], area[1]); y = rng.uniform(area[2], area[3])
            s = rng.uniform(g.get("min", 0.1), g.get("max", 0.3))
            gs = {"type": "box", "size": [s, s * rng.uniform(1, 2.5), s * 0.5],
                  "pos": [x, y, area[4] + s * 0.25], "mat": rng.choice(["DARK", "HULL"]), "detail": 2}
            out.append(gs)
            if g.get("mirror_x", True):
                out.append(mirrored(gs))
    return out

# detail level: 0 = always (all LODs), 1 = LOD0+LOD1, 2 = LOD0 only
LOD_MAX_DETAIL = {0: 2, 1: 1, 2: 0}

def build_lod_mesh(lod, sections):
    bm = bmesh.new()
    for sec in sections:
        if sec.get("detail", 0) > LOD_MAX_DETAIL[lod]:
            continue
        BUILDERS[sec["type"]](bm, sec, bevel=(lod == 0))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(f"{SPEC['id']}_LOD{lod}")
    bm.to_mesh(me); bm.free()
    for name in MAT_ORDER:
        me.materials.append(MATS[name])
    # drop unused material slots so the contract check stays clean
    used = {p.material_index for p in me.polygons}
    obj = bpy.data.objects.new(f"{SPEC['id']}_LOD{lod}", me)
    bpy.context.scene.collection.objects.link(obj)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    return obj, tris, used

# ---------------------------------------------------------------- assemble
root = bpy.data.objects.new(SPEC["id"], None)
root.empty_display_type = "PLAIN_AXES"
bpy.context.scene.collection.objects.link(root)

sections = expand_sections()
lods = SPEC.get("lods", 3)
report = {"id": SPEC["id"], "kind": SPEC.get("kind", "ship"), "class": SPEC.get("class"), "style": SPEC.get("style"), "lods": {}, "hardpoints": [], "markers": []}
for lod in range(lods):
    obj, tris, used = build_lod_mesh(lod, sections)
    obj.parent = root
    report["lods"][f"LOD{lod}"] = tris

def add_empty(name, pos, rot_deg=(0, 0, 0), size=0.3):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = size
    e.location = pos
    e.rotation_euler = [math.radians(a) for a in rot_deg]
    bpy.context.scene.collection.objects.link(e)
    e.parent = root
    return e

DIR_ROT = {"up": (0, 0, 0), "down": (180, 0, 0), "left": (0, -90, 0), "right": (0, 90, 0),
           "forward": (-90, 0, 0), "back": (90, 0, 0)}

counters = {}
for hp in SPEC.get("hardpoints", []):
    targets = [hp] + ([mirrored(hp)] if hp.get("mirror_x") else [])
    for i, h in enumerate(targets):
        key = (h["slot"], h["size"])
        counters[key] = counters.get(key, 0) + 1
        name = f"HP_{h['slot']}_{h['size']}_{counters[key]:02d}"
        d = h.get("dir", "up")
        if i == 1 and d in ("left", "right"):
            d = "right" if d == "left" else "left"
        add_empty(name, h["pos"], DIR_ROT[d])
        report["hardpoints"].append(name)

eng_n = 0
for eng in SPEC.get("engines", []):
    for e in [eng] + ([mirrored(eng)] if eng.get("mirror_x") else []):
        eng_n += 1
        p = e["pos"]
        add_empty(f"ENGINE_{eng_n:02d}", [p[0], p[1] - e["radius"] * 0.7, p[2]], DIR_ROT["back"])
        report["markers"].append(f"ENGINE_{eng_n:02d}")

light_n = 0
for name, pos in SPEC.get("markers", {}).items():
    positions = pos if isinstance(pos[0], list) else [pos]
    for p in positions:
        if name == "LIGHT":
            light_n += 1
            nm = f"LIGHT_{light_n:02d}"
        else:
            nm = name
        add_empty(nm, p)
        report["markers"].append(nm)

# ---------------------------------------------------------------- dimensions
lod0 = bpy.data.objects[f"{SPEC['id']}_LOD0"]
xs = [v.co.x for v in lod0.data.vertices]; ys = [v.co.y for v in lod0.data.vertices]; zs = [v.co.z for v in lod0.data.vertices]
report["dimensions_units"] = {"width_x": round(max(xs) - min(xs), 3), "length_y": round(max(ys) - min(ys), 3),
                              "height_z": round(max(zs) - min(zs), 3)}
report["dimensions_m"] = {k.split("_")[0]: round(v * 10, 1) for k, v in report["dimensions_units"].items()}

# ---------------------------------------------------------------- export
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.context.scene.objects:
    o.select_set(True)
glb_path = os.path.join(OUT_DIR, f"{SPEC['id']}.glb")
bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", use_selection=True,
                          export_yup=True, export_apply=True, export_materials="EXPORT")
report["glb"] = os.path.basename(glb_path)
with open(os.path.join(OUT_DIR, f"{SPEC['id']}.asset.json"), "w") as f:
    json.dump(report, f, indent=2)

# ---------------------------------------------------------------- preview
if PREVIEW:
    for lod in range(1, lods):
        bpy.data.objects[f"{SPEC['id']}_LOD{lod}"].hide_render = True
    L = max(report["dimensions_units"].values())
    cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = L * 1.5
    cam = bpy.data.objects.new("cam", cam_data); bpy.context.scene.collection.objects.link(cam)
    sc = bpy.context.scene; sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_cavity = True
    sc.render.resolution_x = 800; sc.render.resolution_y = 600
    sc.render.film_transparent = False
    sc.render.image_settings.color_mode = "RGB"
    if bpy.context.scene.world is None:
        bpy.context.scene.world = bpy.data.worlds.new("World")
    bpy.context.scene.world.color = (0.18, 0.2, 0.24)
    # two views: front 3/4 and rear 3/4 (engines visible)
    for tag, loc in (("front", (L * 1.2, L * 1.2, L * 0.9)), ("rear", (-L * 1.2, -L * 1.2, L * 0.7))):
        cam.location = loc
        direction = Vector((0, 0, 0)) - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT_DIR, f"{SPEC['id']}_{tag}.png")
        bpy.ops.render.render(write_still=True)

print("BUILD_OK", json.dumps(report))
