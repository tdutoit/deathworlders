class_name SolarView
extends Node3D
## Tactical scope (Solar view, M1 WP8, F21/F22): one system in 3D, tilted over the ecliptic, in the
## white room. Planets are static in M1 (orbital motion is cosmetic, later). Reads state only.

const ORBIT_SCALE := 0.5  # world units per orbit-radius unit
const MOON_SCALE := 1.6
const STAR_SIZE := 6.0
const BODY_SIZE := {"tiny": 1.4, "small": 2.0, "medium": 2.8, "large": 3.6, "huge": 5.4}
const PICK_PX := 26.0
const BEARING_LABELS := {0: "000", 90: "090", 180: "180", 270: "270"}

var state: MatchState
var system_id := 0
var selected_kind := ""
var selected_id := 0

var _bodies := {}  # planet id -> world position
var _units := {}  # unit id -> world position
var _labels := {}  # planet id -> Label
var _bearing_labels: Array = []  # [Label, Vector3]
var _overlay: Control
var _select_mi: MeshInstance3D
var _scope_radius := 100.0


func build(s: MatchState, sid: int) -> void:
	clear()
	state = s
	system_id = sid
	var sys := s.galaxy.system(sid)
	var star := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = STAR_SIZE
	sphere.height = STAR_SIZE * 2
	sphere.radial_segments = 16
	sphere.rings = 8
	star.mesh = sphere
	star.material_override = DrawUtil.ink_material(UiTokens.color("ink_1"))
	add_child(star)
	var halo := MeshInstance3D.new()
	halo.mesh = DrawUtil.ring_mesh(0.86, 48)
	halo.scale = Vector3.ONE * STAR_SIZE * 1.8
	halo.material_override = DrawUtil.ink_material(UiTokens.color("ink_3"))
	add_child(halo)
	var orbits: Array = DrawUtil.new_lines(DrawUtil.ink_material(UiTokens.color("hair")))
	orbits[1].surface_begin(Mesh.PRIMITIVE_LINES)
	var max_r := 40.0
	# Planets first (moons need their parent's position).
	for pid in sys.planet_ids:
		var p := s.galaxy.planet(pid)
		if p.parent_id != StateIO.NONE:
			continue
		var r := p.orbit_radius * ORBIT_SCALE
		max_r = maxf(max_r, r)
		var pos := _on_orbit(Vector3.ZERO, r, pid)
		_bodies[pid] = pos
		DrawUtil.add_circle(orbits[1], Vector3.ZERO, r, 96)
	for pid in sys.planet_ids:
		var p := s.galaxy.planet(pid)
		if p.parent_id == StateIO.NONE:
			continue
		var parent_pos: Vector3 = _bodies[p.parent_id]
		var r: float = BODY_SIZE[s.galaxy.planet(p.parent_id).size] + p.orbit_radius * MOON_SCALE
		_bodies[pid] = _on_orbit(parent_pos, r, pid)
		DrawUtil.add_circle(orbits[1], parent_pos, r, 32)
	_scope_radius = max_r * 1.15 + 10.0
	_add_bearing_ring(orbits[1])
	orbits[1].surface_end()
	add_child(orbits[0])
	for pid: int in _bodies:
		add_child(_planet_mesh(s.galaxy.planet(pid), _bodies[pid]))
	_build_units()
	_select_mi = MeshInstance3D.new()
	_select_mi.mesh = DrawUtil.ring_mesh(0.85, 32)
	_select_mi.material_override = DrawUtil.ink_material(UiTokens.color("ink_1"))
	_select_mi.visible = false
	add_child(_select_mi)
	_build_overlay()



## Hiding a Node3D does not hide CanvasLayers under it, so the labels follow by hand.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and has_node("Labels"):
		(get_node("Labels") as CanvasLayer).visible = is_visible_in_tree()

func clear() -> void:
	for child in get_children():
		remove_child(child)  # detached: free now, so rebuilt nodes keep their names
		child.free()
	_bodies.clear()
	_units.clear()
	_labels.clear()
	_bearing_labels.clear()
	selected_kind = ""
	selected_id = 0
	state = null


func scope_radius() -> float:
	return _scope_radius


## Cosmetic orbit position: golden-angle spread by ID, so it is stable between visits.
static func _on_orbit(center: Vector3, r: float, id: int) -> Vector3:
	var a := fposmod(id * 2.39996, TAU)
	return center + Vector3(cos(a), 0, sin(a)) * r


func _planet_mesh(p: Planet, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var size: float = BODY_SIZE[p.size]
	sphere.radius = size
	sphere.height = size * 2
	sphere.radial_segments = 12
	sphere.rings = 6
	mi.mesh = sphere
	var def: PlanetTypeDef = Database.defs.get_def(StringName(p.planet_type)) if Database.defs else null
	var tone := Color.html(def.color).get_luminance() if def else 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tone, tone, tone).lerp(UiTokens.color("ink_2"), 0.35)
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = pos
	return mi


func _add_bearing_ring(im: ImmediateMesh) -> void:
	var r := _scope_radius
	DrawUtil.add_circle(im, Vector3.ZERO, r, 180)
	for deg in range(0, 360, 10):
		var a := deg_to_rad(deg - 90.0)  # bearing 000 points away from the viewer (screen up)
		var dir := Vector3(cos(a), 0, sin(a))
		var tick := 6.0 if deg % 90 == 0 else 3.0
		im.surface_add_vertex(dir * r)
		im.surface_add_vertex(dir * (r + tick))
		if BEARING_LABELS.has(deg):
			_bearing_labels.append([BEARING_LABELS[deg], dir * (r + 14.0)])


func _build_units() -> void:
	var here := []
	for uid: int in state.units:
		if (state.units.get_or(uid) as Unit).system_id == system_id:
			here.append(uid)
	var mesh := DrawUtil.chevron_mesh()
	var mat := DrawUtil.ink_material(UiTokens.color("ink_1"))
	for i in here.size():
		var a := deg_to_rad(200.0 + i * 12.0)
		var pos := Vector3(cos(a), 0, sin(a)) * _scope_radius * 0.92
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.scale = Vector3.ONE * 3.0
		mi.position = pos
		add_child(mi)
		_units[here[i]] = pos


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Labels"
	layer.layer = 0
	layer.visible = is_visible_in_tree()
	add_child(layer)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_overlay)
	for pid: int in _bodies:
		var p := state.galaxy.planet(pid)
		var l := DrawUtil.overlay_label(p.name, UiTokens.color("ink_2" if p.parent_id else "ink_1"), 13)
		_overlay.add_child(l)
		_labels[pid] = l
	for i in _bearing_labels.size():
		var l := DrawUtil.overlay_label(_bearing_labels[i][0], UiTokens.color("ink_3"), 12)
		_overlay.add_child(l)
		_bearing_labels[i][0] = l


func set_selection(kind: String, id: int) -> void:
	selected_kind = kind
	selected_id = id
	var pos: Variant = _bodies.get(id) if kind == "planet" else (_units.get(id) if kind == "unit" else null)
	_select_mi.visible = pos != null
	if pos != null:
		var r: float = BODY_SIZE[state.galaxy.planet(id).size] * 1.8 if kind == "planet" else 6.0
		_select_mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * r), pos)


func update_view(camera: Camera3D) -> void:
	if state == null:
		return
	for pid: int in _labels:
		var l: Label = _labels[pid]
		var p: Vector3 = _bodies[pid]
		l.visible = not camera.is_position_behind(p)
		var size: float = BODY_SIZE[state.galaxy.planet(pid).size]
		l.position = camera.unproject_position(p + Vector3.BACK * size) + Vector2(-l.size.x * 0.5, 8)
	for entry: Array in _bearing_labels:
		var l: Label = entry[0]
		l.position = camera.unproject_position(entry[1]) - l.size * 0.5


func pick(camera: Camera3D, screen: Vector2) -> Array:
	var pts := {}
	for uid: int in _units:
		pts[uid] = camera.unproject_position(_units[uid])
	var hit := ViewMath.nearest(pts, screen, PICK_PX)
	if hit != 0:
		return ["unit", hit]
	pts.clear()
	for pid: int in _bodies:
		pts[pid] = camera.unproject_position(_bodies[pid])
	hit = ViewMath.nearest(pts, screen, PICK_PX)
	return ["planet", hit] if hit != 0 else ["", 0]
