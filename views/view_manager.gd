class_name ViewManager
extends Node3D
## Owns the three instruments (map = strategic + operational plot, solar = tactical scope) and the
## camera, and turns input actions into navigation, selection and Commands (M1 WP8).
## Mouse: wheel zooms, click selects, click again (or double-click) dives in, right-click orders a
## selected unit to a system or backs out. Keyboard: WASD pans, PageUp/PageDown zoom, Enter dives
## into whatever is under the centre reticle, Esc/Backspace backs out.

const CLUSTER_VIEW_SIZE := 240.0  # view height after diving into a cluster
const FADE_TIME := 0.15

var level := "galaxy"
var focus_cluster := 0
var focus_system := 0
var selected_kind := ""
var selected_id := 0
var reduce_motion := false

var _map_env: Environment
var _solar_env: Environment
var _fade: ColorRect
var _busy := false
var _solar_units: Array = []

@onready var map: MapView = $MapView
@onready var solar: SolarView = $SolarView
@onready var rig: CameraRig = $CameraRig
@onready var world_env: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	_map_env = _environment(false)
	_solar_env = _environment(true)
	world_env.environment = _map_env
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = UiTokens.color("void")
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	EventBus.match_started.connect(_on_match_started)
	EventBus.match_ended.connect(_on_match_ended)
	if GameState.state != null:
		_on_match_started()


## The white room: flat void for the plots; deeper void with soft fog for the scope (F21).
func _environment(solar_scope: bool) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UiTokens.color("void_deep" if solar_scope else "void")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = UiTokens.color("void")
	env.ambient_light_energy = 0.6
	if solar_scope:
		env.fog_enabled = true
		env.fog_light_color = UiTokens.color("void_deep")
		env.fog_density = 0.0015
	return env


func _on_match_started() -> void:
	var state := GameState.state
	solar.clear()
	solar.visible = false
	map.visible = true
	map.build(state)
	rig.set_map_extent(map.extent())
	rig.map_to(Vector2.ZERO, rig.map_size_max * 0.75, true)
	world_env.environment = _map_env
	level = ""
	_select("", 0)


func _on_match_ended() -> void:
	map.clear()
	solar.clear()


func _process(_delta: float) -> void:
	var state := GameState.state
	if state == null:
		return
	if level == "solar":
		solar.update_view(rig.camera)
		var here := _units_in(focus_system)
		if here != _solar_units:  # a unit arrived or left: redraw the scope
			_solar_units = here
			solar.build(state, focus_system)
			solar.set_selection(selected_kind, selected_id)
		return
	map.update_view(rig.camera, rig.current_map_size(), GameClock.tick_fraction())
	var new_level := MapView.level_for(rig.map_size())
	var cid := map.cluster_near(rig.map_center()) if new_level == "cluster" else 0
	map.set_focus_cluster(cid)
	if new_level != level or cid != focus_cluster:
		level = new_level
		focus_cluster = cid
		EventBus.view_changed.emit(level, focus_cluster)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.state == null or _busy:
		return
	if event.is_action_pressed("select") and event is InputEventMouseButton:
		_on_click((event as InputEventMouseButton).position, (event as InputEventMouseButton).double_click)
	elif event.is_action_pressed("context_action") and event is InputEventMouseButton:
		_on_context((event as InputEventMouseButton).position)
	elif event.is_action_pressed("dive"):
		dive_at_center()
	elif event.is_action_pressed("view_up"):
		back()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_click(pos: Vector2, double: bool) -> void:
	var hit: Array = solar.pick(rig.camera, pos) if level == "solar" else map.pick(rig.camera, pos)
	var kind: String = hit[0]
	var id: int = hit[1]
	if kind == "cluster":
		dive_cluster(id)
	elif kind == "system" and (double or (selected_kind == "system" and selected_id == id)):
		dive_system(id)
	else:
		_select(kind, id)


## Right-click: send the selected unit to the system under the cursor, or back out.
func _on_context(pos: Vector2) -> void:
	if level != "solar" and selected_kind == "unit":
		var hit := map.pick(rig.camera, pos)
		if hit[0] == "system":
			CommandQueue.submit_new(CmdMoveUnit.TYPE, {"unit": selected_id, "to": hit[1]})
			return
	back()


func dive_at_center() -> void:
	if level == "solar":
		return
	var hit := map.nearest_to_center(rig.camera)
	if hit[0] == "cluster" and hit[1] != 0:
		dive_cluster(hit[1])
	elif hit[0] == "system" and hit[1] != 0:
		dive_system(hit[1])


func dive_cluster(cid: int) -> void:
	var c := GameState.state.galaxy.cluster(cid)
	rig.map_to(Vector2(c.x, c.y), CLUSTER_VIEW_SIZE)
	_select("cluster", cid)


func dive_system(sid: int) -> void:
	await _fade_out()
	focus_system = sid
	_solar_units = _units_in(sid)
	solar.build(GameState.state, sid)
	map.visible = false
	solar.visible = true
	world_env.environment = _solar_env
	rig.solar_to(solar.scope_radius() * 2.6, true)
	level = "solar"
	_select("system", sid)
	EventBus.view_changed.emit("solar", sid)
	await _fade_in()


## Solar -> cluster plot around that system; cluster -> whole galaxy.
func back() -> void:
	if level == "solar":
		await _fade_out()
		var s := GameState.state.galaxy.system(focus_system)
		solar.clear()
		solar.visible = false
		map.visible = true
		world_env.environment = _map_env
		rig.map_to(Vector2(s.x, s.y), CLUSTER_VIEW_SIZE * 0.8, true)
		level = ""
		_select("system", focus_system)
		await _fade_in()
	elif level == "cluster":
		rig.map_to(Vector2.ZERO, rig.map_size_max * 0.75)
		_select("", 0)


func _select(kind: String, id: int) -> void:
	selected_kind = kind
	selected_id = id
	if level == "solar":
		solar.set_selection(kind, id)
	else:
		map.set_selection(kind, id)
	EventBus.selection_changed.emit(kind, id)


func _units_in(sid: int) -> Array:
	var out := []
	for uid: int in GameState.state.units:
		if (GameState.state.units.get_or(uid) as Unit).system_id == sid:
			out.append(uid)
	return out


func _fade_out() -> void:
	_busy = true
	if reduce_motion:
		return
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await t.finished


func _fade_in() -> void:
	if not reduce_motion:
		var t := create_tween()
		t.tween_property(_fade, "modulate:a", 0.0, FADE_TIME * 1.6)
		await t.finished
	_busy = false
