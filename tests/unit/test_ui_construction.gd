extends GutTest
# M4 WP15: player build controls. The Construction screen (planet buildings, orbitals, shipyard queues) from
# the planet panel and alerts, and "Build at" in the Ship Designer; every button submits a valid Command.

var _main: Node
var _ui: UiRoot


func before_each() -> void:
	GameState.end_match()
	_main = load("res://main.tscn").instantiate()
	add_child_autofree(_main)
	_ui = _main.get_node("UI/UiRoot")
	(_main.get_node("ViewContainer") as ViewManager).reduce_motion = true
	await wait_process_frames(2)
	_ui.main_menu.new_game_requested.emit()
	(_ui.setup.find_child("Start", true, false) as Button).pressed.emit()
	await wait_process_frames(2)


func after_each() -> void:
	GameState.end_match()


func _earth() -> Colony:
	var state := GameState.state
	return state.colony(state.empire(CommandQueue.local_player).capital_planet)


func _yard() -> Station:
	for s: Station in GameState.state.stations.values():
		if s.owner == CommandQueue.local_player and s.def_id == "core:station/shipyard_t1" and s.operational:
			return s
	return null


## Presses a button and returns the Command it submitted (which must validate against the live state).
func _press(b: Button) -> Command:
	CommandQueue.schedule.clear()
	b.pressed.emit()
	assert_eq(CommandQueue.schedule.size(), 1, "%s submits one Command" % b.name)
	var due := CommandQueue.schedule.take_due(GameState.state.tick + 1000000)
	if due.is_empty():
		return null
	assert_true(due[0].validate(GameState.state), "%s: %s" % [b.name, due[0].error])
	return due[0]


func _first(prefix: String) -> Button:
	for b: Button in _ui.construction_screen.find_children(prefix + "*", "Button", true, false):
		return b
	return null


func test_planet_panel_opens_the_construction_screen() -> void:
	EventBus.selection_changed.emit("planet", _earth().id)
	var build := _ui.context_panel.find_child("CTX_BUILD", true, false) as Button
	assert_not_null(build, "own colonies offer Build...")
	build.pressed.emit()
	assert_true(_ui.construction_screen.visible)
	assert_eq(_ui.construction_screen.planet_id, _earth().id)


func test_buildings_queue_reorder_and_cancel() -> void:
	var c := _earth()
	c.buildings.erase("core:building/exchange")  # a free slot
	_ui.open_construction(c.id)
	var add := _first("BAdd_")
	assert_not_null(add, "buildings that fit are offered")
	assert_eq(_press(add).type_id, CmdQueueBuilding.TYPE)
	c.queue.clear()
	for b in ["core:building/farm", "core:building/mine"]:
		c.queue.append(BuildRules.new_construction(GameState.state, "building", b, {}, 90))
	_ui.construction_screen.rebuild()
	assert_eq(_press(_ui.construction_screen.find_child("BUp_1", true, false) as Button).type_id, CmdMoveConstruction.TYPE)
	assert_eq(_press(_ui.construction_screen.find_child("BCancel_0", true, false) as Button).type_id, CmdCancelConstruction.TYPE)


func test_stations_and_shipyard_queue() -> void:
	var y := _yard()
	assert_not_null(y, "the start includes a shipyard")
	_ui.open_construction(y.planet_id)
	var hull := _first("YHull_%d_" % y.id)
	assert_not_null(hull, "civilian hulls are offered at an own shipyard")
	assert_eq(_press(hull).type_id, CmdQueueShip.TYPE)
	var design := _first("YDesign_%d_" % y.id)
	assert_not_null(design, "the empire's standard designs that fit the yard are offered")
	assert_true(_press(design).payload.has("design"))
	# A station on a free body of the home system.
	var state := GameState.state
	var home := state.galaxy.planet(_earth().id).system_id
	var found := false
	for pid in state.galaxy.system(home).planet_ids:
		_ui.open_construction(pid)
		var station := _first("SAdd_")
		if station != null:
			assert_eq(_press(station).type_id, CmdQueueStation.TYPE)
			found = true
			break
	assert_true(found, "some body in the home system takes a station")


func test_idle_shipyard_alert_queues_from_the_construction_screen() -> void:
	var y := _yard()
	y.ship_queue.clear()
	_ui.toggle_screen(_ui.alerts_screen)
	var queue: Button = null
	for b: Button in _ui.alerts_screen.find_children("Queue_*", "Button", true, false):
		queue = b
	assert_not_null(queue, "the idle shipyard alert has Queue (F12)")
	queue.pressed.emit()
	assert_true(_ui.construction_screen.visible, "it opens the Construction screen")
	assert_false(_ui.alerts_screen.visible)


func test_designer_build_at() -> void:
	var state := GameState.state
	_ui.toggle_screen(_ui.designer_screen)  # opens on the empire's first design
	var did: int = _ui.designer_screen._design_id
	assert_ne(did, 0)
	var at := _ui.designer_screen.find_child("BuildAt", true, false) as Button
	assert_not_null(at, "a saved design can be built at a shipyard")
	CommandQueue.schedule.clear()
	at.pressed.emit()
	var due := CommandQueue.schedule.take_due(state.tick + 1000000)
	assert_eq(due.size(), 1)
	assert_true(due[0].validate(state), due[0].error)
	assert_eq(int(due[0].payload["design"]), did)
