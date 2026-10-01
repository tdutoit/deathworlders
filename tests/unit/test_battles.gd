extends GutTest
# M3 WP5: the battle engine (Sub-spec A3–A12; owner decisions 2026-10-01).

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


func _empires(s: MatchState) -> Array:
	return s.empires.keys()


## A neutral system (no owner, no colonies) for a clean fight.
func _arena(s: MatchState) -> int:
	for sid: int in s.galaxy.systems.ordered():
		if s.galaxy.system(sid).owner == StateIO.NONE:
			return sid
	return -1


## A commissioned warship for an empire from a hull and components (or the species' standard design).
func _ship(s: MatchState, eid: int, cls: String, system: int, comps: Array = []) -> Unit:
	var sp: String = s.empire(eid).species.get_slice("/", 1)
	var d: DesignDef = _db.get_def(StringName("core:design/%s_%s_standard" % [sp, cls]))
	var u := Shipyards.spawn(s, eid, String(d.hull), system)
	if comps.is_empty():
		u.components.assign(Array(d.components).map(func(c: StringName) -> String: return String(c)))
	else:
		u.components.assign(comps)
	Fleets.commission(s, u)
	return u


func _war(s: MatchState) -> void:
	var e := _empires(s)
	s.wars[Battles.war_key(e[0], e[1])] = true


func _run(s: MatchState, hours: int) -> void:
	for h in hours:
		s.clear_scratch()
		Battles.tick(s)


func test_damage_pipeline_a9() -> void:
	var s := _match()
	var r := Battles.rules(s)
	var t := Unit.new()
	t.hp = 300
	t.shield = 60
	t.armor = 20
	var kinetic: WeaponFamilyDef = _db.get_def(&"core:weapon_family/kinetic")
	var energy: WeaponFamilyDef = _db.get_def(&"core:weapon_family/energy")
	assert_eq(Battles._damage(s, t, 100, kinetic, 0, r), 33, "60 absorbed, 40 x 100 / (100 + 20)")
	assert_eq([t.shield, t.armor, t.hp], [0, 20, 267], "ablation (40 - 33) / 10 = 0")
	t.shield = 60
	assert_eq(Battles._damage(s, t, 100, energy, 0, r), 13, "energy: 70% vs shields, half armour counts")
	t.shield = 0
	t.armor = 200
	var before := t.armor
	Battles._damage(s, t, 300, kinetic, 60, r)
	assert_lt(t.armor, before, "sustained fire ablates armour")


func test_result_classes_a12() -> void:
	var r: CombatRulesDef = _db.get_def(CombatRulesDef.ID)
	assert_eq(Battles.result(r, 100, 800, true), "decisive_victory")
	assert_eq(Battles.result(r, 800, 100, false), "rout")
	assert_eq(Battles.result(r, 650, 900, true), "pyrrhic_victory")
	assert_eq(Battles.result(r, 300, 350, true), "draw")
	assert_eq(Battles.result(r, 300, 500, true), "victory")
	assert_eq(Battles.result(r, 500, 300, false), "defeat")


func test_no_battle_at_peace_and_battle_at_war() -> void:
	var s := _match()
	var e := _empires(s)
	var arena := _arena(s)
	_ship(s, e[0], "cruiser", arena)
	_ship(s, e[1], "cruiser", arena)
	_run(s, 1)
	assert_eq(s.battles.size(), 0, "empires start at peace")
	_war(s)
	_run(s, 1)
	assert_eq(s.battles.size(), 1, "at war: a battle starts")
	assert_eq((s.battles.values()[0] as Battle).round, 1)


func test_pirates_are_always_hostile() -> void:
	var s := _match()
	var e := _empires(s)
	var arena := _arena(s)
	_ship(s, e[0], "cruiser", arena)
	Pirates.spawn_raider(s, arena, e[0])
	_run(s, 1)
	assert_eq(s.battles.size(), 1)


func test_battle_runs_to_a_report() -> void:
	var s := _match()
	var e := _empires(s)
	var arena := _arena(s)
	_war(s)
	for i in 3:
		_ship(s, e[0], "cruiser", arena)
	_ship(s, e[1], "corvette", arena)
	_run(s, 60)
	assert_eq(s.battles.size(), 0, "over")
	assert_eq(s.reports.size(), 1)
	var rep: Dictionary = (s.reports.values()[0] as BattleReport).data
	assert_eq(rep["owners"], [e[0], e[1]])
	assert_true(String(rep["results"][0]).ends_with("victory"), "3 cruisers beat a corvette: %s" % rep["results"][0])
	assert_eq(rep["lost"].size() + rep["retreated"].size() > 0, true)
	assert_gt(rep["rounds"], 0)
	assert_eq(rep["strength"].size(), rep["rounds"])
	assert_gt(s.empire(e[0]).tech_fragments, -1)


func test_battles_are_deterministic() -> void:
	var reports := []
	for run in 2:
		var s := _match()
		var e := _empires(s)
		var arena := _arena(s)
		_war(s)
		for i in 3:
			_ship(s, e[0], "destroyer", arena)
			_ship(s, e[1], "destroyer", arena)
		_run(s, 60)
		reports.append(JSON.stringify((s.reports.values()[0] as BattleReport).data))
	assert_eq(reports[0], reports[1])


func test_point_defence_intercepts_missiles() -> void:
	var s := _match()
	var e := _empires(s)
	var arena := _arena(s)
	_war(s)
	var pd := "core:component/point_defence"
	var mp := "core:component/missile_pod_m"
	for i in 2:
		_ship(s, e[0], "destroyer", arena, ["", "", mp, "", ""])
		_ship(s, e[1], "frigate", arena, ["", pd, pd, ""])
	_run(s, 3)
	var b: Battle = s.battles.values()[0]
	var fam: Dictionary = b.log["family"][0]
	assert_true(fam.has("core:weapon_family/missile"))
	assert_gt(fam["core:weapon_family/missile"][2], 0, "some missiles intercepted (A8)")


func test_formation_retreats_at_its_threshold() -> void:
	var s := _match()
	var e := _empires(s)
	var arena := _arena(s)
	_war(s)
	var weak := _ship(s, e[1], "corvette", arena)
	(s.fleets.get_or(weak.fleet) as Fleet).retreat_at = 250
	for i in 4:
		_ship(s, e[0], "cruiser", arena)
	_run(s, 60)
	var rep: Dictionary = (s.reports.values()[0] as BattleReport).data
	assert_true(rep["retreated"].size() > 0 or rep["lost"].size() > 0, "it retreats or dies")
	if s.units.has(weak.id):
		assert_true(weak.is_moving() or weak.system_id != arena, "survivors head home")


func test_boarding_captures_a_crippled_ship() -> void:
	var s := _match()
	var e := _empires(s)
	var arena := _arena(s)
	_war(s)
	var assault := _ship(s, e[0], "assault", arena, ["", "", "core:component/marine_barracks", "core:component/marine_barracks"])
	var victim := _ship(s, e[1], "corvette", arena, ["", "", ""])
	victim.hp = 10  # crippled
	(s.fleets.get_or(victim.fleet) as Fleet).retreat_at = 0  # stays
	_run(s, 1)
	var b: Battle = s.battles.values()[0]
	b.band = 2  # Close (A11)
	_run(s, 30)
	assert_eq(victim.owner, e[0], "captured")
	assert_eq(s.battles.size(), 0)
	assert_ne(victim.fleet, StateIO.NONE, "joins the captor's reserve after the battle")
	assert_eq((s.fleets.get_or(victim.fleet) as Fleet).owner, e[0])
	assert_eq(assault.owner, e[0])


func test_interdiction_stops_a_passing_fleet() -> void:
	var s := _match()
	var e := _empires(s)
	_war(s)
	var home := s.galaxy.planet(s.empire(e[0]).capital_planet).system_id
	var hops := AutoLogistics._hops_from(s, home, {})
	var mid := -1
	var far := -1
	for sid: int in IdMap.sort_keys(hops.keys()):
		if hops[sid] == 1 and mid < 0:
			mid = sid
	for sid: int in IdMap.sort_keys(hops.keys()):
		if hops[sid] == 2 and Pathfinder.route(s.galaxy, home, sid).has(mid) and far < 0:
			far = sid
	var blocker := _ship(s, e[1], "cruiser", mid)
	var mover := _ship(s, e[0], "corvette", home)
	var cmd := CommandRegistry.create(CmdMoveFleet.TYPE, e[0], {"fleet": mover.fleet, "to": far})
	Sim.execute(s, [cmd] as Array[Command])
	assert_eq(cmd.error, "")
	for h in 24 * 10:
		s.clear_scratch()
		Movement.tick(s)
	assert_eq(mover.system_id, mid, "stopped by the hostile cruiser")
	assert_false(mover.is_moving())
	assert_ne(blocker.id, 0)


func test_save_and_load_mid_battle() -> void:
	var s := _match()
	var e := _empires(s)
	var arena := _arena(s)
	_war(s)
	for i in 2:
		_ship(s, e[0], "cruiser", arena)
		_ship(s, e[1], "cruiser", arena)
	_run(s, 3)
	var back := MatchState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	back.defs = _db
	assert_eq(back.checksum(), s.checksum(), "a saved battle round-trips through JSON")
	_run(s, 5)
	_run(back, 5)
	assert_eq(back.checksum(), s.checksum(), "and continues identically")


func test_defence_platform_fights() -> void:
	var s := _match()
	var e := _empires(s)
	_war(s)
	var home := s.galaxy.planet(s.empire(e[0]).capital_planet)
	var st := Station.new()
	st.id = s.alloc_id()
	st.owner = e[0]
	st.def_id = "core:station/defence_platform_t1"
	st.system_id = home.system_id
	st.planet_id = home.id
	st.operational = true
	s.stations.put(st.id, st)
	Battles.arm_station(s, st)
	assert_eq(st.hp, 1200)
	_ship(s, e[1], "corvette", home.system_id)
	_run(s, 1)
	var b: Battle = s.battles.values()[0]
	assert_true(st.id in b.active(0), "the platform is in the battle")
