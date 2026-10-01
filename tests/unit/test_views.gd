extends GutTest
# M1 WP8: views read state, navigation works by mouse and keyboard actions, picking and orders.

var _main: Node
var _vm: ViewManager


func before_each() -> void:
	_main = load("res://main.tscn").instantiate()
	add_child_autofree(_main)
	_vm = _main.get_node("ViewContainer")
	_vm.reduce_motion = true
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	settings.add_player(1, "core:species/krothi", "ai")
	assert_eq(GameState.start_new_match(settings, 1234), [] as Array[String])
	await wait_process_frames(2)


func after_each() -> void:
	GameState.end_match()


func _action(name: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e


func _home() -> int:
	var human: Empire = GameState.state.empires.get_or(GameState.first_human_empire())
	return GameState.state.galaxy.planet(human.capital_planet).system_id


func test_map_built_from_state() -> void:
	var g := GameState.state.galaxy
	assert_eq(_vm.map._systems_mm.multimesh.instance_count, g.systems.size())
	assert_eq(_vm.map._clusters_mm.multimesh.instance_count, g.clusters.size())
	assert_eq(_vm.map._system_labels.size(), g.systems.size())
	assert_eq(_vm.level, "galaxy")


func test_levels_follow_zoom() -> void:
	assert_eq(MapView.level_for(2000.0), "galaxy")
	assert_eq(MapView.level_for(MapView.CLUSTER_LEVEL_SIZE - 1.0), "cluster")


func test_dive_cluster_then_system_then_back_out() -> void:
	var s := GameState.state.galaxy.system(_home())
	_vm.dive_cluster(s.cluster_id)
	await wait_process_frames(2)
	assert_eq(_vm.level, "cluster")
	assert_eq(_vm.focus_cluster, s.cluster_id)
	await _vm.dive_system(s.id)
	assert_eq(_vm.level, "solar")
	assert_true(_vm.solar.visible)
	assert_false(_vm.map.visible)
	assert_eq(_vm.solar._bodies.size(), s.planet_ids.size())
	await _vm.back()
	await wait_process_frames(2)
	assert_eq(_vm.level, "cluster")
	assert_true(_vm.map.visible)
	_vm.back()
	_vm.rig.map_to(_vm.rig.map_center(), _vm.rig.map_size(), true)  # skip the easing
	await wait_process_frames(2)
	assert_eq(_vm.level, "galaxy")


func test_keyboard_only_reaches_every_view() -> void:
	var s := GameState.state.galaxy.system(_home())
	var c := GameState.state.galaxy.cluster(s.cluster_id)
	_vm.rig.map_to(Vector2(c.x, c.y), _vm.rig.map_size(), true)
	await wait_process_frames(2)
	_vm._unhandled_input(_action("dive"))  # Enter: dive into the cluster under the reticle
	_vm.rig.map_to(Vector2(s.x, s.y), _vm.rig.map_size(), true)
	await wait_process_frames(2)
	assert_eq(_vm.level, "cluster")
	_vm._unhandled_input(_action("dive"))  # Enter again: the system under the reticle
	await wait_process_frames(2)
	assert_eq(_vm.level, "solar")
	assert_eq(_vm.focus_system, s.id)
	_vm._unhandled_input(_action("view_up"))  # Esc: back out
	await wait_process_frames(2)
	assert_eq(_vm.level, "cluster")


func test_pick_system_under_screen_point() -> void:
	var s := GameState.state.galaxy.system(_home())
	_vm.rig.map_to(Vector2(s.x, s.y), 200.0, true)
	await wait_process_frames(2)
	var screen := _vm.rig.camera.unproject_position(ViewMath.world(s.x, s.y))
	var hit := _vm.map.pick(_vm.rig.camera, screen + Vector2(3, 3))
	assert_true(hit[0] == "system" or hit[0] == "unit", str(hit))
	assert_eq(_vm.map.pick(_vm.rig.camera, Vector2(-500, -500)), ["", 0])


func test_right_click_orders_selected_unit() -> void:
	var state := GameState.state
	var home := _home()
	Sim.execute(state, [CommandRegistry.create(CmdDebugSpawnScout.TYPE, CommandQueue.local_player, {"system": home})] as Array[Command])
	var scout_id: int = state.units.keys()[-1]  # the scout just spawned (start ships come first)
	var target_id: int = state.galaxy.lane(state.galaxy.system(home).lane_ids[0]).other_end(home)
	var target := state.galaxy.system(target_id)
	# Headless viewports are 64 px tall: zoom right in so the scout and the target are far apart on screen.
	_vm.rig.map_to(Vector2(target.x, target.y), CameraRig.MAP_SIZE_MIN, true)
	await wait_process_frames(2)
	_vm._select("unit", scout_id)
	var at := _vm.rig.camera.unproject_position(ViewMath.world(target.x, target.y))
	_vm._on_context(at)
	assert_eq(CommandQueue.schedule.size(), 1, "a move_unit command was queued")
	var due := CommandQueue.schedule.take_due(state.tick + CommandSchedule.DELAY)
	assert_eq(due[0].type_id, CmdMoveUnit.TYPE)
	assert_eq(due[0].payload, {"unit": scout_id, "to": target_id})


func test_selection_is_broadcast() -> void:
	watch_signals(EventBus)
	_vm._select("system", _home())
	assert_signal_emitted_with_parameters(EventBus, "selection_changed", ["system", _home()])


func test_units_interpolate_between_ticks() -> void:
	var state := GameState.state
	var home := _home()
	Sim.execute(state, [CommandRegistry.create(CmdDebugSpawnScout.TYPE, CommandQueue.local_player, {"system": home})] as Array[Command])
	var u: Unit = state.units.values()[-1]
	var target: int = state.galaxy.lane(state.galaxy.system(home).lane_ids[0]).other_end(home)
	Sim.execute(state, [CommandRegistry.create(CmdMoveUnit.TYPE, CommandQueue.local_player, {"unit": u.id, "to": target})] as Array[Command])
	var a := ViewMath.unit_point(state, u, 0.0)
	var b := ViewMath.unit_point(state, u, 1.0)
	var hs := state.galaxy.system(home)
	assert_eq(a, Vector2(hs.x, hs.y), "at the start of the lane before any tick")
	assert_gt(b.distance_to(a), 0.0, "moves within the hour")
