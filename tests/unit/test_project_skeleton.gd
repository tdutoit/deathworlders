extends GutTest
# M1 WP1: project skeleton contract (folders, autoloads, main scene, InputMap).

const M1_ACTIONS: Array[String] = [
	"select", "context_action", "zoom_in", "zoom_out",
	"pan_up", "pan_down", "pan_left", "pan_right",
	"view_up", "pause", "speed_up", "speed_down", "open_menu",
]
const AUTOLOADS: Array[String] = ["GameClock", "GameState", "EventBus", "Database", "CommandQueue"]
const FOLDERS: Array[String] = [
	"res://sim", "res://data/core", "res://views", "res://ui", "res://assets/models",
	"res://assets/shaders", "res://tools/blender", "res://tests", "res://mods", "res://loc",
]


func test_folder_layout() -> void:
	for path: String in FOLDERS:
		assert_true(DirAccess.dir_exists_absolute(path), "missing folder " + path)


func test_autoloads_registered() -> void:
	for autoload_name: String in AUTOLOADS:
		assert_true(ProjectSettings.has_setting("autoload/" + autoload_name), "autoload " + autoload_name)
		assert_not_null(get_tree().root.get_node_or_null(autoload_name), "autoload node " + autoload_name)


func test_main_scene_structure() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_eq(main_path, "res://main.tscn")
	var main: Node = (load(main_path) as PackedScene).instantiate()
	assert_true(main.get_node_or_null("ViewContainer") is Node3D, "ViewContainer")
	assert_true(main.get_node_or_null("UI") is CanvasLayer, "UI layer")
	main.free()


func test_m1_input_actions_bound() -> void:
	for action: String in M1_ACTIONS:
		assert_true(InputMap.has_action(action), "action " + action)
		if InputMap.has_action(action):
			assert_gt(InputMap.action_get_events(action).size(), 0, "binding for " + action)


func test_pause_action_matches_space() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	assert_true(event.is_action("pause"))
