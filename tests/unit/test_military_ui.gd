extends GutTest
# M3 WP12: military UI helpers (read-only views and the designer's matchup prediction).

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _design(id: String) -> Array:
	var d: DesignDef = _db.get_def(StringName(id))
	return [String(d.hull), Array(d.components).map(func(c: StringName) -> String: return String(c))]


func test_prediction_runs_twenty_battles() -> void:
	var a := _design("core:design/human_cruiser_standard")
	var b := _design("core:design/krothi_cruiser_standard")
	var r := MatchupPredictor.predict(_db, a[0], a[1], b[0], b[1])
	assert_false(r.has("error"))
	assert_eq(int(r["win"]) + int(r["loss"]) + int(r["draw"]), 100)
	assert_eq(int(r["ships_a"]), 4)
	assert_between(int(r["ships_b"]), 1, 12)
	assert_eq(MatchupPredictor.predict(_db, a[0], a[1], b[0], b[1]), r, "seeded: the same answer every time")


func test_unarmed_design_is_not_predicted() -> void:
	var a := _design("core:design/human_cruiser_standard")
	var empty: Array = []
	for c in a[1]:
		empty.append("")
	assert_true(MatchupPredictor.predict(_db, a[0], empty, a[0], a[1]).has("error"))


func test_fleet_summary_helpers() -> void:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	var eid: int = s.empires.keys()[0]
	var home := s.galaxy.planet(s.empire(eid).capital_planet).system_id
	var ids := []
	for cls in ["cruiser", "destroyer", "destroyer"]:
		var d := _design("core:design/human_%s_standard" % cls)
		var u := Shipyards.spawn(s, eid, d[0], home)
		u.components.assign(d[1])
		Fleets.arm(s, u)
		ids.append(u.id)
	var f := Fleets.create(s, eid, ids)
	var comp := UiFleets.composition(s, f.task_forces[0])
	assert_true(comp.begins_with("1 ") and ", 2 " in comp, "capital classes first: %s" % comp)
	var c := UiFleets.condition(s, f)
	assert_eq(c[0], c[1], "fresh ships: full hull")
	assert_gt(UiFleets.strength(s, f), 0)
	assert_true(UiFleets.supplied(s, f))
	assert_eq(FleetsScreen._nearby_own(s, eid, home)[0], home, "patrol starts where the fleet is")


func test_battle_report_helpers() -> void:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	var eid: int = s.empires.keys()[0]
	var home := s.galaxy.planet(s.empire(eid).capital_planet).system_id
	var ids := []
	for i in 3:
		var d := _design("core:design/human_cruiser_standard")
		var u := Shipyards.spawn(s, eid, d[0], home)
		u.components.assign(d[1])
		Fleets.arm(s, u)
		ids.append(u.id)
	Fleets.create(s, eid, ids)
	Pirates.spawn_raider(s, home, eid)
	for h in 120:
		s.clear_scratch()
		Battles.tick(s)
	assert_eq(s.reports.size(), 1)
	var d: Dictionary = (s.reports.values()[0] as BattleReport).data
	assert_eq((d["bands"] as Array).size(), (d["strength"] as Array).size(), "a range band per round")
	var side: int = (d["owners"] as Array).find(eid)
	var moments := BattlesScreen.moments(d, side)
	assert_gt(moments.size(), 0, "something happened")
	for m: Array in moments:
		assert_true(String(m[0]).begins_with("MOMENT_"))
	var mvp := BattlesScreen.mvp_of(d, eid)
	assert_true(mvp == "" or int(d["names"][mvp][0]) == eid)
	assert_ne(BattlesScreen._losses(d, 1 - side), "", "enemy losses listed")


## The three M3 screens open on a live match with a fleet, designs and a report, without script errors.
func test_screens_open() -> void:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	settings.add_player(1, "core:species/krothi", "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	var eid: int = s.empires.keys()[0]
	var home := s.galaxy.planet(s.empire(eid).capital_planet).system_id
	var d := _design("core:design/human_cruiser_standard")
	var ids := []
	for i in 2:
		var u := Shipyards.spawn(s, eid, d[0], home)
		u.components.assign(d[1])
		Fleets.arm(s, u)
		ids.append(u.id)
	Fleets.create(s, eid, ids)
	Pirates.spawn_raider(s, home, eid)
	for h in 120:
		s.clear_scratch()
		Battles.tick(s)
	var saved_state := GameState.state
	var saved_player := CommandQueue.local_player
	GameState.state = s
	CommandQueue.local_player = eid
	for screen: ScreenPanel in [FleetsScreen.new(), DesignerScreen.new(), BattlesScreen.new()]:
		add_child_autofree(screen)
		screen.open()
		assert_gt(screen._body.get_child_count(), 1, "%s filled" % screen.get_script().get_global_name())
		screen.close()
	var fs := FleetsScreen.new()
	add_child_autofree(fs)
	fs._tab = "empires"
	fs.open()
	assert_not_null(fs._body.find_child("War_*", true, false), "war toggle offered")
	GameState.state = saved_state
	CommandQueue.local_player = saved_player
