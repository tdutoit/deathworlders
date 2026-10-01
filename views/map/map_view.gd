class_name MapView
extends Node3D
## Strategic plot (Galaxy) and operational plot (Cluster) in one orthographic map (M1 WP8, F21/F22).
## Zoomed out: clusters, corridors and a lettered square grid. Zoomed in below CLUSTER_LEVEL_SIZE:
## systems, lanes, labels and range rings around the focused cluster. Reads state; never writes it.

const CLUSTER_LEVEL_SIZE := 360.0  # view heights below this are the operational plot
const GRID_STEP := 200
const SYSTEM_PX := 5.0
const CAPITAL_PX := 7.0
const CLUSTER_PX := 16.0
const UNIT_PX := 9.0
const SELECT_PX := 13.0
const PICK_PX := 16.0
const RING_STEP := 25  # range ring spacing in lane units

var state: MatchState
var level := "galaxy"
var focus_cluster := 0
var selected_kind := ""
var selected_id := 0

var _system_ids: Array = []
var _systems_mm: MultiMeshInstance3D
var _owned_mm: MultiMeshInstance3D
var _clusters_mm: MultiMeshInstance3D
var _units_mm: MultiMeshInstance3D
var _select_mi: MeshInstance3D
var _lanes_mat: StandardMaterial3D
var _systems_mat: StandardMaterial3D
var _rings_im: ImmediateMesh
var _overlay: Control
var _system_labels := {}  # id -> Label
var _cluster_labels := {}  # id -> Label
var _grid_labels: Array = []  # [Label, Vector3]
var _drawn_size := -1.0


func build(s: MatchState) -> void:
	clear()
	state = s
	var g := s.galaxy
	_system_ids = g.systems.keys()
	_systems_mat = DrawUtil.ink_material(UiTokens.color("ink_1"))
	_systems_mm = _multimesh(DrawUtil.disc_mesh(), _systems_mat, _system_ids.size())
	var owned := _system_ids.filter(func(id: int) -> bool: return g.system(id).owner != 0)
	_owned_mm = _multimesh(DrawUtil.ring_mesh(0.72), DrawUtil.ink_material(UiTokens.color("ink_1")), owned.size())
	_owned_mm.set_meta("ids", owned)
	_clusters_mm = _multimesh(DrawUtil.ring_mesh(0.9, 40), DrawUtil.ink_material(UiTokens.color("ink_2")), g.clusters.size())
	_units_mm = _multimesh(DrawUtil.chevron_mesh(), DrawUtil.ink_material(UiTokens.color("ink_1")), 0)
	_select_mi = MeshInstance3D.new()
	_select_mi.mesh = DrawUtil.ring_mesh(0.8, 32)
	_select_mi.material_override = DrawUtil.ink_material(UiTokens.color("ink_1"))
	_select_mi.visible = false
	add_child(_select_mi)
	_build_lines()
	_build_overlay()
	set_selection("", 0)



## Hiding a Node3D does not hide CanvasLayers under it, so the labels follow by hand.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and has_node("Labels"):
		(get_node("Labels") as CanvasLayer).visible = is_visible_in_tree()

func clear() -> void:
	for child in get_children():
		remove_child(child)  # detached: free now, so rebuilt nodes keep their names
		child.free()
	_system_labels.clear()
	_cluster_labels.clear()
	_grid_labels.clear()
	_drawn_size = -1.0
	state = null


func _multimesh(mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _build_lines() -> void:
	var g := state.galaxy
	_lanes_mat = DrawUtil.ink_material(UiTokens.color("hair"))
	var lanes: Array = DrawUtil.new_lines(_lanes_mat)
	var corridors: Array = DrawUtil.new_lines(DrawUtil.ink_material(UiTokens.color("ink_3")))
	lanes[1].surface_begin(Mesh.PRIMITIVE_LINES)
	corridors[1].surface_begin(Mesh.PRIMITIVE_LINES)
	for lid: int in g.lanes:
		var l := g.lane(lid)
		var im: ImmediateMesh = corridors[1] if lid in g.corridors else lanes[1]
		var a := g.system(l.a)
		var b := g.system(l.b)
		im.surface_add_vertex(ViewMath.world(a.x, a.y) + Vector3.DOWN)
		im.surface_add_vertex(ViewMath.world(b.x, b.y) + Vector3.DOWN)
	lanes[1].surface_end()
	corridors[1].surface_end()
	add_child(lanes[0])
	add_child(corridors[0])
	# Square coordinate grid for the strategic plot.
	var grid: Array = DrawUtil.new_lines(DrawUtil.ink_material(Color(UiTokens.color("hair"), 0.55)))
	grid[0].name = "Grid"
	var extent := _extent()
	var n := ceili(extent / GRID_STEP)
	grid[1].surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-n, n + 1):
		grid[1].surface_add_vertex(Vector3(i * GRID_STEP, -2, -n * GRID_STEP))
		grid[1].surface_add_vertex(Vector3(i * GRID_STEP, -2, n * GRID_STEP))
		grid[1].surface_add_vertex(Vector3(-n * GRID_STEP, -2, i * GRID_STEP))
		grid[1].surface_add_vertex(Vector3(n * GRID_STEP, -2, i * GRID_STEP))
	grid[1].surface_end()
	add_child(grid[0])
	for col in range(-n, n):
		for row in range(-n, n):
			var ref := "%s%d" % [String.chr(65 + col + n), row + n + 1]
			_grid_labels.append([ref, Vector3(col * GRID_STEP + 6, 0, row * GRID_STEP + 6)])
	# Range rings for the operational plot (rebuilt when the focus cluster changes).
	var rings: Array = DrawUtil.new_lines(DrawUtil.ink_material(Color(UiTokens.color("hair"), 0.8)))
	rings[0].name = "Rings"
	_rings_im = rings[1]
	add_child(rings[0])


## Radius that contains every system (for camera limits and the grid).
func _extent() -> float:
	var r := 0.0
	for sid: int in state.galaxy.systems:
		var s := state.galaxy.system(sid)
		r = maxf(r, Vector2(s.x, s.y).length())
	return r + 100.0


func extent() -> float:
	return _extent()


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
	for cid: int in state.galaxy.clusters:
		var l := DrawUtil.overlay_label(state.galaxy.cluster(cid).name, UiTokens.color("ink_1"), 16)
		_overlay.add_child(l)
		_cluster_labels[cid] = l
	for sid in _system_ids:
		var l := DrawUtil.overlay_label(state.galaxy.system(sid).name, UiTokens.color("ink_2"), 13)
		_overlay.add_child(l)
		_system_labels[sid] = l
	for i in _grid_labels.size():
		var l := DrawUtil.overlay_label(_grid_labels[i][0], UiTokens.color("ink_3"), 12)
		_overlay.add_child(l)
		_grid_labels[i][0] = l


static func level_for(size: float) -> String:
	return "cluster" if size < CLUSTER_LEVEL_SIZE else "galaxy"


func set_selection(kind: String, id: int) -> void:
	selected_kind = kind
	selected_id = id
	_drawn_size = -1.0


func set_focus_cluster(cid: int) -> void:
	if cid == focus_cluster:
		return
	focus_cluster = cid
	_rings_im.clear_surfaces()
	var c := state.galaxy.cluster(cid) if cid != 0 else null
	if c == null:
		return
	_rings_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for r in range(RING_STEP, 4 * RING_STEP + 1, RING_STEP):
		DrawUtil.add_circle(_rings_im, ViewMath.world(c.x, c.y) + Vector3.DOWN * 3, r * 1.0, 96)
	_rings_im.surface_end()


## Per frame: marker sizes for the zoom, unit positions between ticks, label placement.
func update_view(camera: Camera3D, size: float, frac: float) -> void:
	if state == null:
		return
	var vh := get_viewport().get_visible_rect().size.y
	var px := size / vh  # world units per screen pixel
	var new_level := level_for(size)
	if new_level != level or absf(size - _drawn_size) > _drawn_size * 0.02:
		level = new_level
		_drawn_size = size
		_layout_markers(px)
	_layout_units(px, frac)
	_layout_labels(camera)


func _layout_markers(px: float) -> void:
	var g := state.galaxy
	var galaxy := level == "galaxy"
	_systems_mat.albedo_color = UiTokens.color("ink_3" if galaxy else "ink_1")
	_lanes_mat.albedo_color = Color(UiTokens.color("hair"), 0.5 if galaxy else 1.0)
	var mm := _systems_mm.multimesh
	for i in _system_ids.size():
		var s := g.system(_system_ids[i])
		var r := (CAPITAL_PX if s.owner != 0 else SYSTEM_PX) * px * (0.6 if galaxy else 1.0)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, 1, r)), ViewMath.world(s.x, s.y)))
	var owned: Array = _owned_mm.get_meta("ids")
	for i in owned.size():
		var s := g.system(owned[i])
		var r := (CAPITAL_PX + 4.0) * px
		_owned_mm.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, 1, r)), ViewMath.world(s.x, s.y)))
	var cids: Array = g.clusters.keys()
	_clusters_mm.visible = galaxy
	for i in cids.size():
		var c := g.cluster(cids[i])
		var r := CLUSTER_PX * px
		_clusters_mm.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, 1, r)), ViewMath.world(c.x, c.y)))
	get_node("Grid").visible = galaxy
	get_node("Rings").visible = not galaxy
	_select_mi.visible = selected_kind in ["system", "cluster", "unit"]
	if selected_kind == "system":
		var s := g.system(selected_id)
		_select_mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * SELECT_PX * px), ViewMath.world(s.x, s.y) + Vector3.UP)
	elif selected_kind == "cluster":
		var c := g.cluster(selected_id)
		_select_mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * (CLUSTER_PX + 5) * px), ViewMath.world(c.x, c.y) + Vector3.UP)


func _layout_units(px: float, frac: float) -> void:
	var mm := _units_mm.multimesh
	var ids: Array = state.units.keys()
	if mm.instance_count != ids.size():
		mm.instance_count = ids.size()
	var r := UNIT_PX * px
	for i in ids.size():
		var u: Unit = state.units.get_or(ids[i])
		var p := ViewMath.unit_point(state, u, frac)
		var offset := Vector3(0, 2, -r * 1.6) if not u.is_moving() else Vector3(0, 2, 0)
		var basis := Basis(Vector3.UP, -ViewMath.unit_heading(state, u)).scaled(Vector3(r, 1, r))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, 0, p.y) + offset))
		if selected_kind == "unit" and ids[i] == selected_id:
			_select_mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * SELECT_PX * px), Vector3(p.x, 1, p.y) + offset)


func _layout_labels(camera: Camera3D) -> void:
	var rect := get_viewport().get_visible_rect().grow(40)
	var galaxy := level == "galaxy"
	for cid: int in _cluster_labels:
		var c := state.galaxy.cluster(cid)
		var l: Label = _cluster_labels[cid]
		l.visible = galaxy
		if galaxy:
			_place(l, camera.unproject_position(ViewMath.world(c.x, c.y)) + Vector2(0, 26))
	for sid: int in _system_labels:
		var l: Label = _system_labels[sid]
		var s := state.galaxy.system(sid)
		var p := camera.unproject_position(ViewMath.world(s.x, s.y))
		l.visible = not galaxy and rect.has_point(p)
		if l.visible:
			_place(l, p + Vector2(0, 16))
	for entry: Array in _grid_labels:
		var l: Label = entry[0]
		l.visible = galaxy
		if galaxy:
			l.position = camera.unproject_position(entry[1])


static func _place(l: Label, center: Vector2) -> void:
	l.position = center - Vector2(l.size.x * 0.5, 0)


## What is under a screen point: ["unit" | "system" | "cluster", id] or ["", 0].
func pick(camera: Camera3D, screen: Vector2) -> Array:
	var units := {}
	for uid: int in state.units:
		var p := ViewMath.unit_point(state, state.units.get_or(uid), 0.0)
		units[uid] = camera.unproject_position(Vector3(p.x, 0, p.y))
	var hit := ViewMath.nearest(units, screen, PICK_PX * 0.8)
	if hit != 0:
		return ["unit", hit]
	if level == "galaxy":
		hit = ViewMath.nearest(_cluster_screen(camera), screen, PICK_PX * 2.0)
		return ["cluster", hit] if hit != 0 else ["", 0]
	hit = ViewMath.nearest(_system_screen(camera), screen, PICK_PX)
	return ["system", hit] if hit != 0 else ["", 0]


## The cluster (galaxy level) or system (cluster level) nearest the screen centre (keyboard "dive").
func nearest_to_center(camera: Camera3D) -> Array:
	var center := get_viewport().get_visible_rect().size * 0.5
	if level == "galaxy":
		return ["cluster", ViewMath.nearest(_cluster_screen(camera), center, INF)]
	return ["system", ViewMath.nearest(_system_screen(camera), center, INF)]


## Cluster whose centre is nearest a map point.
func cluster_near(point: Vector2) -> int:
	var pts := {}
	for cid: int in state.galaxy.clusters:
		var c := state.galaxy.cluster(cid)
		pts[cid] = Vector2(c.x, c.y)
	return ViewMath.nearest(pts, point, INF)


func _cluster_screen(camera: Camera3D) -> Dictionary:
	var pts := {}
	for cid: int in state.galaxy.clusters:
		var c := state.galaxy.cluster(cid)
		pts[cid] = camera.unproject_position(ViewMath.world(c.x, c.y))
	return pts


func _system_screen(camera: Camera3D) -> Dictionary:
	var pts := {}
	for sid in _system_ids:
		var s := state.galaxy.system(sid)
		pts[sid] = camera.unproject_position(ViewMath.world(s.x, s.y))
	return pts
