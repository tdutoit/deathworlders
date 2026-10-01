class_name CameraRig
extends Node3D
## The one camera (M1 WP8). MAP mode: orthographic, looking straight down at the galaxy plane, with
## pan/zoom easing toward targets. SOLAR mode: perspective, tilted 22 degrees over the ecliptic
## (Sub-spec F22 "tactical scope"). Input comes from InputMap actions only.

enum Mode { MAP, SOLAR }

const ZOOM_STEP := 1.25
const PAN_SPEED := 0.8  # view heights per second
const EASE := 10.0
const MAP_SIZE_MIN := 50.0
const SOLAR_PITCH_DEG := 22.0
const SOLAR_DIST_MIN := 60.0
const SOLAR_DIST_MAX := 900.0

var mode := Mode.MAP
var map_size_max := 2000.0
var map_bounds := 1000.0  # pan limit (distance from origin)

var _center := Vector2.ZERO
var _size := 1000.0
var _target_center := Vector2.ZERO
var _target_size := 1000.0
var _distance := 400.0
var _target_distance := 400.0
var _dragging := false

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.far = 20000.0
	_apply()


func set_map_extent(radius: float) -> void:
	map_bounds = radius
	map_size_max = radius * 2.6


## Ease (or jump) the map camera to a centre point and view height.
func map_to(center: Vector2, size: float, instant := false) -> void:
	mode = Mode.MAP
	_target_center = _clamp_center(center)
	_target_size = clampf(size, MAP_SIZE_MIN, map_size_max)
	if instant:
		_center = _target_center
		_size = _target_size
	_apply()


func solar_to(distance: float, instant := false) -> void:
	mode = Mode.SOLAR
	_target_distance = clampf(distance, SOLAR_DIST_MIN, SOLAR_DIST_MAX)
	if instant:
		_distance = _target_distance
	_apply()


func map_center() -> Vector2:
	return _target_center


func map_size() -> float:
	return _target_size


## Current (eased) view height, for sizing markers.
func current_map_size() -> float:
	return _size


func zoom(steps: float) -> void:
	var factor := pow(ZOOM_STEP, -steps)
	if mode == Mode.MAP:
		_target_size = clampf(_target_size * factor, MAP_SIZE_MIN, map_size_max)
	else:
		_target_distance = clampf(_target_distance * factor, SOLAR_DIST_MIN, SOLAR_DIST_MAX)


## Ground point under a screen position (MAP mode).
func screen_to_map(screen: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen)
	return Vector2(origin.x, origin.z)


func _process(delta: float) -> void:
	var pan := Input.get_vector("pan_left", "pan_right", "pan_up", "pan_down")
	if mode == Mode.MAP and pan != Vector2.ZERO:
		_target_center = _clamp_center(_target_center + pan * _target_size * PAN_SPEED * delta)
	var k := 1.0 - exp(-EASE * delta)
	_center = _center.lerp(_target_center, k)
	_size = lerpf(_size, _target_size, k)
	_distance = lerpf(_distance, _target_distance, k)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		zoom(1.0)
	elif event.is_action_pressed("zoom_out"):
		zoom(-1.0)
	elif event.is_action_pressed("pan_drag"):
		_dragging = true
	elif event.is_action_released("pan_drag"):
		_dragging = false
	elif event is InputEventMouseMotion and _dragging and mode == Mode.MAP:
		var px_to_world := _size / get_viewport().get_visible_rect().size.y
		_target_center = _clamp_center(_target_center - (event as InputEventMouseMotion).relative * px_to_world)
		_center = _target_center
	else:
		return
	get_viewport().set_input_as_handled()


func _clamp_center(c: Vector2) -> Vector2:
	return c.limit_length(map_bounds)


func _apply() -> void:
	if camera == null:
		return
	if mode == Mode.MAP:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = _size
		camera.near = 1.0
		camera.look_at_from_position(Vector3(_center.x, 5000.0, _center.y), Vector3(_center.x, 0.0, _center.y), Vector3.FORWARD)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 40.0
		camera.near = 0.5
		var pitch := deg_to_rad(SOLAR_PITCH_DEG)
		camera.look_at_from_position(Vector3(0.0, sin(pitch), cos(pitch)) * _distance, Vector3.ZERO, Vector3.UP)
