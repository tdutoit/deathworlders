extends GutTest
# M2 WP1: economy Defs and core data match Sub-spec B (and its 2026-10-01 change log).

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	assert_false(loader.report.has_errors(), loader.report.format_text())
	_db = loader.db


func _def(id: String) -> Def:
	return _db.get_def(StringName("core:" + id))


func _res(m: Dictionary, name: String) -> int:
	return int(m.get(StringName("core:resource/" + name), 0))


func test_counts() -> void:
	assert_eq(_db.ids("job").size(), 11)
	assert_eq(_db.ids("building").size(), 12)
	assert_eq(_db.ids("focus").size(), 8)
	assert_eq(_db.ids("synergy").size(), 5)
	assert_eq(_db.ids("station").size(), 15, "14 + Defensive Platform (M3 WP1)")
	assert_eq(_db.ids("directive").size(), 7)
	assert_eq(_db.ids("template").size(), 8 * 7 + 1, "every ordered focus pair + colony default")


func test_jobs_match_b3() -> void:
	var worker: JobDef = _def("job/worker")
	assert_eq(_res(worker.outputs, "alloys"), 3)
	assert_eq(_res(worker.inputs, "ore"), 6)
	var engineer: JobDef = _def("job/engineer")
	assert_eq([_res(engineer.outputs, "components"), _res(engineer.inputs, "alloys"), _res(engineer.inputs, "rare_earths")], [2, 1, 1])
	assert_eq(_res((_def("job/farmer") as JobDef).outputs, "food"), 6)
	assert_eq(_res((_def("job/munitions_worker") as JobDef).outputs, "munitions"), 8)
	assert_eq(_res((_def("job/clerk") as JobDef).outputs, "credits"), 4)
	assert_eq((_def("job/dockworker") as JobDef).modifiers.size(), 2, "berths + stockpile cap")


func test_buildings() -> void:
	var farm: BuildingDef = _def("building/farm")
	assert_eq(farm.jobs, {&"core:job/farmer": 3})
	assert_eq(_res(farm.cost, "alloys"), 80)
	assert_eq(farm.build_days, 90)
	assert_eq(_res(farm.upkeep, "credits"), 1)
	assert_eq((_def("building/re_mine") as BuildingDef).requires_deposit, &"core:resource/rare_earths")
	var capital: BuildingDef = _def("building/capital")
	assert_false(capital.buildable)
	assert_false(capital.uses_slot)
	assert_eq([_res(capital.outputs, "credits"), _res(capital.outputs, "research"), _res(capital.outputs, "influence")], [20, 40, 3])
	var slot_mod: ModifierDef = capital.modifiers[0]
	assert_eq([slot_mod.key, slot_mod.value], [&"planet.building_slots", 2], "capital +2 slots (B change log)")


func test_focus_and_synergy() -> void:
	var logistics: FocusDef = _def("focus/logistics")
	assert_eq(logistics.bonus_permille, 500)
	var berths: ModifierDef = logistics.modifiers[0]
	assert_eq([berths.key, berths.value], [&"planet.freighter_berths", 4], "+4 berths (B6)")
	var forge: SynergyDef = _def("synergy/forge_world")
	assert_true(forge.matches(&"core:focus/industrial", &"core:focus/mining"))
	assert_true(forge.matches(&"core:focus/mining", &"core:focus/industrial"), "either order")
	assert_false(forge.matches(&"core:focus/industrial", &"core:focus/farming"))


func test_stations_and_tiers() -> void:
	var t2: StationDef = _def("station/shipyard_t2")
	assert_eq([t2.docks, t2.shipyard_size, t2.tier], [2, &"M", 2])
	assert_eq([_res(t2.cost, "alloys"), _res(t2.cost, "components")], [400, 80], "x2 the base row")
	assert_eq(_res((_def("station/logistics_t1") as StationDef).upkeep, "credits"), 2)
	assert_eq(_res((_def("station/logistics_t3") as StationDef).upkeep, "credits"), 6)
	assert_eq(_res((_def("station/outpost") as StationDef).upkeep, "credits"), 1)
	assert_eq((_def("station/logistics_t1") as StationDef).upgrades_to, &"core:station/logistics_t2")
	assert_eq((_def("station/logistics_t3") as StationDef).upgrades_to, &"")
	assert_eq([(_def("station/depot_t1") as StationDef).supply_range, (_def("station/depot_t3") as StationDef).supply_range], [2, 4])
	assert_eq(_res((_def("station/mining_belt") as StationDef).outputs, "ore"), 15)


func test_civilian_hulls() -> void:
	var light: HullDef = _def("hull/freighter_light")
	assert_eq([light.role, light.cargo_capacity, light.lane_speed], [&"freighter", 100, 6])
	assert_eq([_res(light.upkeep, "credits"), _res(light.upkeep, "fuel")], [1, 1])
	var colony: HullDef = _def("hull/colony_ship")
	assert_eq([colony.pop_cost, _res(colony.cost, "food")], [1, 50])
	assert_eq((_def("hull/human_corvette_mk1") as HullDef).role, &"warship", "M1 hull keeps its default role")


func test_templates_cover_every_pair() -> void:
	var foci := _db.ids("focus")
	for p: String in foci:
		for s: String in foci:
			if p != s:
				var id := "core:template/%s_%s" % [p.get_slice("/", 1), s.get_slice("/", 1)]
				assert_true(_db.has(StringName(id)), id)
	var colony: TemplateDef = _def("template/colony_default")
	assert_eq(colony.build_order.slice(0, 2), [&"core:building/farm", &"core:building/mine"] as Array[StringName], "D2: Farm + Mine")


func test_pace_scaling() -> void:
	assert_eq(Pace.scale(80, 600), 48)
	assert_eq(Pace.scale(90, 1600), 144)
	assert_eq(Pace.scale(1, 600), 1, "never below 1")
	assert_eq(Pace.scale(0, 600), 0)
	assert_eq(Pace.scale_map({&"x": 100, &"y": 5}, 1600), {&"x": 160, &"y": 8})


func test_bad_economy_defs_fail_readably() -> void:
	var loader := ContentLoader.new()
	loader.load_mods(["res://tests/fixtures/mods/bad_economy_mod"] as Array[String])
	var r := loader.report
	for fragments: Array in [["lopsided", "must pair up"], ["temple", "core:focus/religion", "does not exist"],
			["odd_upgrade", "same function, one tier higher"], ["empty_freighter", "cargo_capacity"],
			["half_pair", "primary and secondary"], ["self_love", "must differ"]]:
		assert_true(r.has_error_containing(fragments), "%s\n%s" % [fragments, r.format_text()])
