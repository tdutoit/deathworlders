extends GutTest
# M3 WP3: warships and fleets (main spec 7.1, 7.6; owner decisions 2026-10-01).

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	settings.add_player(1, "core:species/krothi", "ai")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _human(s: MatchState) -> Empire:
	return s.empires.values()[0]


func _home(s: MatchState) -> int:
	return s.galaxy.planet(_human(s).capital_planet).system_id


## A commissioned warship of the human empire's standard design for that class, at the capital.
func _ship(s: MatchState, cls: String, system := -1) -> Unit:
	var d: DesignDef = _db.get_def(StringName("core:design/human_%s_standard" % cls))
	var u := Shipyards.spawn(s, _human(s).id, String(d.hull), _home(s) if system < 0 else system)
	u.components.assign(Array(d.components).map(func(c: StringName) -> String: return String(c)))
	Fleets.commission(s, u)
	return u


func _do(s: MatchState, type: StringName, payload: Dictionary) -> Command:
	var cmd := CommandRegistry.create(type, _human(s).id, payload)
	Sim.execute(s, [cmd] as Array[Command])
	return cmd


func _fleets(s: MatchState) -> Array:
	return s.fleets.values().filter(func(f: Fleet) -> bool: return f.owner == _human(s).id)


func test_commissioned_ships_join_the_system_reserve() -> void:
	var s := _match()
	var a := _ship(s, "cruiser")
	assert_eq(a.hp, 1500)
	assert_eq(a.armor, 60 + 80)
	assert_eq(a.shield, 200 + 250)
	assert_eq(a.crew, 40)
	assert_ne(a.fleet, StateIO.NONE)
	var b := _ship(s, "corvette")
	assert_eq(b.fleet, a.fleet, "new ships join the reserve fleet in their system")
	var f: Fleet = s.fleets.get_or(a.fleet)
	assert_true(f.reserve)


func test_auto_grouping_by_class_capital_first() -> void:
	var s := _match()
	var ids: Array[int] = []
	for i in 7:
		ids.append(_ship(s, "corvette").id)
	ids.append(_ship(s, "cruiser").id)
	ids.append(_ship(s, "battleship").id)
	var f: Fleet = s.fleets.get_or((s.units.get_or(ids[0]) as Unit).fleet)
	var squads: Array = []
	for tf: Array in f.task_forces:
		squads.append_array(tf)
	assert_eq(squads.size(), 4, "battleship | cruiser | 6 corvettes | 1 corvette")
	assert_eq(squads[0], [ids[8]] as Array[int], "capital classes first")
	assert_eq((squads[2] as Array).size(), 6, "squadrons hold at most 6")
	assert_eq(f.task_forces.size(), 1, "4 squadrons fit one task force")


func test_create_merge_split_rename() -> void:
	var s := _match()
	var a := _ship(s, "cruiser")
	var b := _ship(s, "destroyer")
	var c := _ship(s, "corvette")
	assert_eq(_do(s, CmdCreateFleet.TYPE, {"ships": [a.id, b.id], "name": "Hammer"}).error, "")
	var hammer: Fleet = s.fleets.get_or(a.fleet)
	assert_eq(hammer.name, "Hammer")
	assert_eq(hammer.size(), 2)
	assert_eq(c.fleet != hammer.id, true)
	assert_eq(_do(s, CmdMergeFleets.TYPE, {"into": hammer.id, "from": c.fleet}).error, "")
	assert_eq(hammer.size(), 3)
	assert_eq(_fleets(s).size(), 1, "the merged fleet is gone")
	assert_eq(_do(s, CmdSplitFleet.TYPE, {"fleet": hammer.id, "ships": [c.id], "name": "Picket"}).error, "")
	assert_eq(hammer.size(), 2)
	assert_eq((s.fleets.get_or(c.fleet) as Fleet).name, "Picket")
	assert_ne(_do(s, CmdSplitFleet.TYPE, {"fleet": hammer.id, "ships": [a.id, b.id]}).error, "", "not all ships")
	assert_eq(_do(s, CmdRenameFleet.TYPE, {"fleet": hammer.id, "name": "Anvil"}).error, "")
	assert_eq(hammer.name, "Anvil")


func test_doctrine() -> void:
	var s := _match()
	var f: Fleet = s.fleets.get_or(_ship(s, "cruiser").fleet)
	assert_eq(_do(s, CmdSetDoctrine.TYPE, {"fleet": f.id, "range": "standoff", "target": "escorts", "retreat": 250,
		"formation": "sphere", "stance": "defensive"}).error, "")
	assert_eq([f.range_pref, f.target_priority, f.retreat_at, f.formation, f.stance], ["standoff", "escorts", 250, "sphere", "defensive"])
	assert_ne(_do(s, CmdSetDoctrine.TYPE, {"fleet": f.id, "range": "orbit"}).error, "")
	assert_ne(_do(s, CmdSetDoctrine.TYPE, {"fleet": f.id, "retreat": 300}).error, "")


func test_move_squadron_between_task_forces() -> void:
	var s := _match()
	var f: Fleet = s.fleets.get_or(_ship(s, "cruiser").fleet)
	_ship(s, "corvette")
	assert_eq(f.task_forces.size(), 1)
	assert_eq(_do(s, CmdMoveSquadron.TYPE, {"fleet": f.id, "task_force": 0, "squadron": 1, "to": 1}).error, "")
	assert_eq(f.task_forces.size(), 2, "a new task force")
	assert_eq(_do(s, CmdMoveSquadron.TYPE, {"fleet": f.id, "task_force": 1, "squadron": 0, "to": 0}).error, "")
	assert_eq(f.task_forces.size(), 1, "the emptied task force is gone")


func test_fleet_moves_together_at_slowest_speed() -> void:
	var s := _match()
	var fast := _ship(s, "corvette")  # speed 8
	var slow := _ship(s, "battleship")  # speed 4
	var f: Fleet = s.fleets.get_or(fast.fleet)
	var target: int = s.galaxy.system(_home(s)).lane_ids.map(func(l: int) -> int: return s.galaxy.lane(l).other_end(_home(s)))[0]
	assert_eq(_do(s, CmdMoveFleet.TYPE, {"fleet": f.id, "to": target}).error, "")
	assert_false(f.reserve, "a fleet that leaves stops collecting new ships")
	assert_eq(Fleets.move_speed(s, f.id), 4 * 1000 / 24, "battleship lane speed")
	Movement.tick(s)
	assert_eq(fast.progress, slow.progress, "in step")
	slow.out_of_fuel = true
	s.clear_scratch()
	assert_eq(Fleets.move_speed(s, f.id), 4 * 1000 / 24 / 2, "half speed while any ship is out of fuel")
	slow.out_of_fuel = false
	for h in 24 * 20:
		s.clear_scratch()
		Movement.tick(s)
	assert_eq(fast.system_id, target)
	assert_eq(slow.system_id, target)
	assert_ne(_do(s, CmdMoveUnit.TYPE, {"unit": fast.id, "to": _home(s)}).error, "", "fleet ships move with the fleet")


func test_fleet_size_limit() -> void:
	var s := _match()
	var ids := []
	for i in 121:
		var u := Shipyards.spawn(s, _human(s).id, "core:hull/human_corvette_mk1", _home(s))
		ids.append(u.id)
	assert_true(Fleets.fits(s, ids.slice(0, 120)), "5 task forces x 4 squadrons x 6 corvettes")
	assert_false(Fleets.fits(s, ids))
	assert_ne(_do(s, CmdCreateFleet.TYPE, {"ships": ids}).error, "")


func test_fractional_ship_upkeep() -> void:
	var s := _match()
	_ship(s, "frigate")
	var due: Dictionary = Shipyards.upkeep(s)
	var freighters := 0
	for u: Unit in s.units.values():
		if u.owner == _human(s).id and u.kind == "freighter":
			freighters += 1000 * int((_db.get_def(StringName(u.hull_id)) as HullDef).upkeep.get(&"core:resource/credits", 0))
	assert_eq(due[_human(s).id] - freighters, 1500, "B10: a frigate costs 1.5 credits a month")


func test_fleets_survive_save_and_load() -> void:
	var s := _match()
	var a := _ship(s, "cruiser")
	_ship(s, "corvette")
	_do(s, CmdSetDoctrine.TYPE, {"fleet": a.fleet, "range": "close"})
	var back := MatchState.from_dict(s.to_dict())
	assert_eq(back.checksum(), s.checksum())
	assert_eq((back.fleets.get_or(a.fleet) as Fleet).range_pref, "close")
	assert_eq((back.units.get_or(a.id) as Unit).hp, 1500)
