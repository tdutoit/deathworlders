class_name UiSettings
extends RefCounted
## Client-only display settings, saved in user://settings.cfg (never part of the sim).

const PATH := "user://settings.cfg"
const SCALES: Array[float] = [1.0, 1.25, 1.5]


static func ui_scale() -> float:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return float(cfg.get_value("ui", "scale", 1.0))


static func set_ui_scale(scale: float, tree: SceneTree) -> void:
	tree.root.content_scale_factor = scale
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("ui", "scale", scale)
	cfg.save(PATH)
