extends GutTest
# M2 WP7a: sectors, reach, colony stages and the default governor (Sub-spec D2-D4, D9).

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _human(s: MatchState) -> Empire:
	return s.empires.values()[0]


func _home_sys(s: MatchState) -> int:
	return s.galaxy.planet(_human(s).capital_planet).system_id


func _do(s: MatchState, type_id: StringName, payload: Dictionary) -> Command:
	var cmd := CommandRegistry.create(type_id, _human(s).id, payload)
	Sim.execute(s, [cmd] as Array[Command])
	return cmd


## An owned colony with `pops` humans on the first planet of a system `hops` lanes from home.
func _colony_at(s: MatchState, hops: int, pops: int) -> Colony:
	var dist := AutoLogistics._hops_from(s, _home_sys(s), {})
	for sid: int in IdMap.sort_keys(dist.keys()):
		if dist[sid] == hops:
			var sys := s.galaxy.system(sid)
			sys.owner = _human(s).id
			var c := Colony.new()
			c.id = sys.planet_ids[0]
			c.owner = _human(s).id
			c.pops = {_human(s).species: pops}
			s.colonies.put(c.id, c)
			Sectors.update_membership(s)
			return c
	return null


func test_core_sector_at_start() -> void:
	var s := _match()
	assert_eq(s.sectors.size(), 1)
	var core: Sector = s.sectors.values()[0]
	assert_eq(core.hub, _human(s).capital_planet)
	assert_has(core.systems, _home_sys(s))
	assert_eq(Sectors.range_of(s, core), 3)


func test_reach_bands() -> void:
	var r := Economy.rules(_db)
	assert_eq(Sectors.reach_effects(r, 2), [0, 0] as Array[int])
	assert_eq(Sectors.reach_effects(r, 3), [100, -5] as Array[int])
	assert_eq(Sectors.reach_effects(r, 5), [250, -15] as Array[int])
	assert_eq(Sectors.reach_effects(r, 9), [400, -25] as Array[int])


func test_far_station_costs_more_upkeep() -> void:
	var s := _match()
	var far := _colony_at(s, 3, 1)
	var before: int = StationOps.upkeep(s)[_human(s).id]
	StartSetup._place_built(s, _human(s).id, far.id, "core:station/outpost")
	assert_eq(StationOps.upkeep(s)[_human(s).id] - before, 1100, "1 credit +100 permille at reach 3")


func test_stages() -> void:
	var s := _match()
	var c := _colony_at(s, 1, 5)
	Governor.update_stage(s, c)
	assert_eq(c.stage, "colony", "5 pops but not 5 years old yet")
	c.founded_tick = s.tick - 5 * Calendar.HOURS_PER_YEAR
	Governor.update_stage(s, c)
	assert_eq(c.stage, "developed")
	c.pops = {_human(s).species: 15}
	c.stability = 59
	Governor.update_stage(s, c)
	assert_eq(c.stage, "developed", "Core needs stability 60")
	c.stability = 60
	Governor.update_stage(s, c)
	assert_eq(c.stage, "core")
	c.pops = {_human(s).species: 4}
	Governor.update_stage(s, c)
	assert_eq(c.stage, "colony", "losing pops drops the stage")


func test_governor_sets_focus_and_builds() -> void:
	var s := _match()
	var c := _colony_at(s, 1, 6)
	c.founded_tick = s.tick - 5 * Calendar.HOURS_PER_YEAR
	s.galaxy.planet(c.id).deposits["core:resource/ore"] = 2
	var core: Sector = s.sectors.values()[0]
	_do(s, CmdSetDirective.TYPE, {"sector": core.id, "directive": "core:directive/industrial_core"})
	Governor.month_tick(s)
	assert_eq([c.primary_focus, c.secondary_focus], ["core:focus/industrial", "core:focus/mining"])
	assert_eq(c.queue.size(), 1, "the template's first building is queued")
	assert_eq(c.queue[0].def_id, "core:building/farm")


func test_colony_stage_uses_the_default_template() -> void:
	var s := _match()
	var c := _colony_at(s, 1, 1)
	s.galaxy.planet(c.id).deposits["core:resource/ore"] = 1
	Governor.month_tick(s)
	assert_eq(c.primary_focus, "", "no focus before Developed")
	assert_eq(c.queue[0].def_id, "core:building/farm", "D2: Farm first")


func test_assisted_and_manual() -> void:
	var s := _match()
	var c := _colony_at(s, 1, 1)
	assert_eq(_do(s, CmdSetAutonomy.TYPE, {"planet": c.id, "autonomy": "assisted"}).error, "")
	Governor.month_tick(s)
	assert_true(c.queue.is_empty())
	assert_eq(c.suggestion, "core:building/farm")
	assert_eq(_do(s, CmdApproveSuggestion.TYPE, {"planet": c.id}).error, "")
	assert_eq(c.queue[0].def_id, "core:building/farm")
	var m := _colony_at(s, 2, 1)
	_do(s, CmdSetAutonomy.TYPE, {"planet": m.id, "autonomy": "manual"})
	Governor.month_tick(s)
	assert_true(m.queue.is_empty())
	assert_eq(m.suggestion, "")


func test_pinned_template() -> void:
	var s := _match()
	var c := _colony_at(s, 1, 1)
	assert_eq(_do(s, CmdPinTemplate.TYPE, {"planet": c.id, "template": "core:template/research_economy"}).error, "")
	Governor.month_tick(s)
	assert_eq(c.queue[0].def_id, "core:building/farm")
	assert_string_contains(_do(s, CmdPinTemplate.TYPE, {"planet": c.id, "template": "core:template/nope"}).error, "unknown template")


func test_create_sector_rules_and_cap() -> void:
	var s := _match()
	var hub: Station = BuildRules.stations_at(s, _human(s).capital_planet)[0]
	assert_string_contains(_do(s, CmdCreateSector.TYPE, {"hub": hub.id}).error, "T2")
	var far := _colony_at(s, 4, 3)
	far.primary_focus = "core:focus/logistics"
	assert_eq(_do(s, CmdCreateSector.TYPE, {"hub": far.id}).error, "")
	assert_eq(s.sectors.size(), 2)
	assert_has((s.sectors.values()[1] as Sector).systems, s.galaxy.planet(far.id).system_id)
	hub.def_id = "core:station/logistics_t2"
	assert_string_contains(_do(s, CmdCreateSector.TYPE, {"hub": hub.id}).error, "cap")


func test_reach_lowers_stability() -> void:
	var s := _match()
	var near := _colony_at(s, 1, 3)
	var far := _colony_at(s, 3, 3)
	for c in [near, far]:
		c.stockpile.add("core:resource/food", 50000)
	Economy.month_tick(s)
	assert_eq(near.stability - far.stability, 5, "reach 3: -5 stability")
