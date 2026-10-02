class_name DesignPreview
extends SubViewportContainer
## The Ship Designer's 3D preview (F10): the hull's low-poly model, slowly turning, with each fitted
## weapon's turret model on its slot's hardpoint (C11: a hardpoint's +Y is the mount direction).

const TURN_SPEED := 0.25  # radians per second

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _note: Label
var _shown := ""


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(360, 280)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	add_child(_viewport)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	_viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.76)
	_viewport.add_child(env)
	_note = UiKit.label("DESIGNER_NO_MODEL", "Caption")
	_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_note.visible = false
	add_child(_note)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_pivot.rotate_y(TURN_SPEED * delta)


## Rebuilds the model only when the hull or the fitted parts change.
func show_design(hull: HullDef, components: Array) -> void:
	var key := "%s|%s" % [hull.id if hull else &"", ",".join(components)]
	if key == _shown:
		return
	_shown = key
	for c in _pivot.get_children():
		c.queue_free()
	var path := "res://" + hull.model.trim_prefix("res://") if hull != null and hull.model != "" else ""
	_note.visible = path == "" or not ResourceLoader.exists(path)
	if _note.visible:
		return
	var model := (load(path) as PackedScene).instantiate() as Node3D
	_pivot.add_child(model)
	for i in mini(components.size(), hull.slots.size()):
		var comp := Database.defs.get_def(StringName(components[i])) as ComponentDef if components[i] != "" else null
		var hp := model.find_child(String(hull.slots[i].hardpoint), true, false) as Node3D
		if comp == null or comp.model == "" or hp == null:
			continue
		var tpath := "res://" + comp.model.trim_prefix("res://")
		if ResourceLoader.exists(tpath):
			hp.add_child((load(tpath) as PackedScene).instantiate())
	_pivot.rotation = Vector3.ZERO
	var aabb := _bounds(model)
	var extent := maxf(aabb.size.length(), 1.0)
	_camera.size = extent * 0.9
	_camera.position = aabb.get_center() + Vector3(extent, extent * 0.7, extent)
	_camera.look_at(aabb.get_center())


## Shows only LOD0 meshes (hull and turrets) and returns their bounds in model space.
static func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*_LOD*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.visible = mi.name.ends_with("LOD0")
		if not mi.visible:
			continue
		var box := (root.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
