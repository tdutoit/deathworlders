class_name DrawUtil
extends RefCounted
## Mesh and material helpers for the Control Room look: flat unshaded ink on the void.


static func ink_material(color: Color, vertex_colors := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.vertex_color_use_as_albedo = vertex_colors
	if color.a < 1.0 or vertex_colors:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Flat disc of radius 1 on the XZ plane.
static func disc_mesh(segments := 16) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		verts.append_array([Vector3.ZERO, Vector3(cos(a1), 0, sin(a1)), Vector3(cos(a0), 0, sin(a0))])
	return _mesh(verts, Mesh.PRIMITIVE_TRIANGLES)


## Flat ring (annulus) with inner radius `inner` and outer radius 1 on the XZ plane.
static func ring_mesh(inner := 0.8, segments := 24) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		verts.append_array([o0, o1, o0 * inner, o1, o1 * inner, o0 * inner])
	return _mesh(verts, Mesh.PRIMITIVE_TRIANGLES)


## Chevron pointing along +X on the XZ plane (fleet/unit glyph, F22).
static func chevron_mesh() -> ArrayMesh:
	var tip := Vector3(1, 0, 0)
	var l := Vector3(-0.8, 0, -0.8)
	var r := Vector3(-0.8, 0, 0.8)
	var notch := Vector3(-0.3, 0, 0)
	return _mesh(PackedVector3Array([tip, l, notch, tip, notch, r]), Mesh.PRIMITIVE_TRIANGLES)


## Hollow diamond (freighter glyph, F22) of radius 1 on the XZ plane.
static func diamond_mesh(inner := 0.55) -> ArrayMesh:
	var verts := PackedVector3Array()
	var pts := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
	for i in 4:
		var o0: Vector3 = pts[i]
		var o1: Vector3 = pts[(i + 1) % 4]
		verts.append_array([o0, o1, o0 * inner, o1, o1 * inner, o0 * inner])
	return _mesh(verts, Mesh.PRIMITIVE_TRIANGLES)


static func _mesh(verts: PackedVector3Array, primitive: Mesh.PrimitiveType) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(primitive, arrays)
	return mesh


## Appends an XZ-plane circle (as line segments) to an ImmediateMesh surface begun with PRIMITIVE_LINES.
static func add_circle(im: ImmediateMesh, center: Vector3, radius: float, segments := 64) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		im.surface_add_vertex(center + Vector3(cos(a0), 0, sin(a0)) * radius)
		im.surface_add_vertex(center + Vector3(cos(a1), 0, sin(a1)) * radius)


static func new_lines(material: Material) -> Array:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = material
	return [mi, im]


## A screen-space label (Control) kept over a 3D point by the owning view.
static func overlay_label(text: String, color: Color, font_size := 14) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
