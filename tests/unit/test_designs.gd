extends GutTest
# M3 WP2: ship designs (main spec 7.4, C5): stats, commands, standard designs, building, sharing.

const CORVETTE := "core:hull/human_corvette_mk1"
const CRUISER := "core:hull/human_cruiser_mk1"
const AC := "core:component/autocannon_s"
const RAIL := "core:component/railgun_m"
const ARMOR := "core:component/armor_plate"
const SHIELD := "core:component/shield_gen"
const MARINES := "core:component/marine_barracks"

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


func _do(s: MatchState, eid: int, type: StringName, payload: Dictionary) -> Command:
	var cmd := CommandRegistry.create(type, eid, payload)
	Sim.execute(s, [cmd] as Array[Command])
	return cmd


func _designs_of(s: MatchState, eid: int) -> Array:
	return s.designs.values().filter(func(d: ShipDesign) -> bool: return d.owner == eid)


func _shipyard(s: MatchState, eid: int) -> Station:
	for st: Station in s.stations.values():
		if st.owner == eid and (_db.get_def(StringName(st.def_id)) as StationDef).function == &"shipyard":
			return st
	return null


func test_stats_sum_hull_and_modules() -> void:
	var st := ShipStats.of(_db, CRUISER, [AC, RAIL, RAIL, ARMOR, SHIELD, "", ""])
	assert_eq(st.hull, 1350, "A2 1500, x0.9 (M4 WP1 species balance); no species: no traits")
	assert_eq(st.armor, 60 + 80, "Armour Plating +80 (A2)")
	assert_eq(st.shield, 200 + 250, "Shield Generator +250 (A2)")
	assert_eq(st.shield_regen, 50, "A1 default")
	assert_eq(st.crew, 40, "M hull crew placeholder")
	assert_eq(st.weapons.size(), 3)
	assert_eq(st.ammo, 0, "no ammo weapons")
	var missiles := ShipStats.of(_db, "core:hull/human_destroyer_mk1", [AC, AC, "core:component/missile_pod_m", ARMOR, ""])
	assert_eq(missiles.ammo, 20, "20 ammo per ammo-using weapon")
	var assault := ShipStats.of(_db, "core:hull/human_assault_mk1", [AC, ARMOR, MARINES, MARINES])
	assert_eq(assault.marines, 120)
	assert_eq(assault.crew, 40 + 60)


func test_cost_is_hull_plus_components() -> void:
	var c := ShipStats.cost(_db, CORVETTE, [AC, AC, ARMOR])
	assert_eq(c["core:resource/alloys"], 72 + 10 + 10 + 20, "hull 60 x1.2 (M4 WP1)")
	assert_eq(c["core:resource/components"], 12 + 5 + 5 + 5)


func test_empires_start_with_their_species_standard_designs() -> void:
	var s := _match()
	var human := _human(s)
	var mine := _designs_of(s, human.id)
	assert_eq(mine.size(), 8, "one per combat class")
	for d: ShipDesign in mine:
		assert_true(d.hull.begins_with("core:hull/human_"), d.hull)
		assert_true(d.source.begins_with("core:design/human_"))
	var krothi: Empire = s.empires.values()[1]
	assert_true(_designs_of(s, krothi.id).all(func(d: ShipDesign) -> bool: return d.hull.begins_with("core:hull/krothi_")))


func test_save_edit_delete() -> void:
	var s := _match()
	var eid := _human(s).id
	var before := _designs_of(s, eid).size()
	var ok := _do(s, eid, CmdSaveDesign.TYPE, {"name": "Hammer", "hull": CRUISER, "components": [AC, RAIL, RAIL, ARMOR, ARMOR, "", ""]})
	assert_eq(ok.error, "")
	assert_eq(_designs_of(s, eid).size(), before + 1)
	var d: ShipDesign = _designs_of(s, eid).filter(func(x: ShipDesign) -> bool: return x.name == "Hammer")[0]
	assert_eq(_do(s, eid, CmdSaveDesign.TYPE, {"design": d.id, "name": "Hammer v2", "hull": CRUISER,
		"components": [AC, RAIL, RAIL, ARMOR, SHIELD, "", ""]}).error, "")
	assert_eq(d.name, "Hammer v2")
	assert_eq(d.components[4], SHIELD)
	assert_eq(_do(s, eid, CmdDeleteDesign.TYPE, {"design": d.id}).error, "")
	assert_null(s.designs.get_or(d.id))


func test_invalid_designs_are_rejected() -> void:
	var s := _match()
	var eid := _human(s).id
	var bad := [
		{"name": "x", "hull": CRUISER, "components": [RAIL, RAIL, RAIL, ARMOR, ARMOR, "", ""]},  # railgun in a small slot
		{"name": "x", "hull": "core:hull/krothi_cruiser_mk1", "components": ["", "", "", "", "", "", ""]},  # other species
		{"name": "x", "hull": "core:hull/freighter_light", "components": []},  # not a warship
		{"name": "", "hull": CORVETTE, "components": [AC, AC, ARMOR]},  # no name
		{"name": "x", "hull": CORVETTE, "components": [AC, AC]},  # slot count
		{"name": "x", "hull": CORVETTE, "components": [AC, AC, "core:component/nope"]},
	]
	for p in bad:
		assert_ne(_do(s, eid, CmdSaveDesign.TYPE, p).error, "", str(p))
	var krothi: Empire = s.empires.values()[1]
	var theirs: ShipDesign = _designs_of(s, krothi.id)[0]
	assert_ne(_do(s, eid, CmdDeleteDesign.TYPE, {"design": theirs.id}).error, "", "not yours")


func test_build_a_design_at_a_shipyard() -> void:
	var s := _match()
	var eid := _human(s).id
	var yard := _shipyard(s, eid)
	var corvette: ShipDesign = _designs_of(s, eid).filter(func(d: ShipDesign) -> bool: return d.hull == CORVETTE)[0]
	var cruiser: ShipDesign = _designs_of(s, eid).filter(func(d: ShipDesign) -> bool: return d.hull == CRUISER)[0]
	assert_ne(_do(s, eid, CmdQueueShip.TYPE, {"station": yard.id, "design": cruiser.id}).error, "",
		"a cruiser needs a size M shipyard (B10)")
	assert_eq(_do(s, eid, CmdQueueShip.TYPE, {"station": yard.id, "design": corvette.id}).error, "")
	var b: Construction = yard.ship_queue[-1]
	assert_eq(b.design, corvette.id)
	assert_eq(b.components, corvette.components)
	assert_eq(b.cost["core:resource/alloys"], 112 * 1000, "hull + components, milli")
	# Editing the design afterwards doesn't change the queued ship.
	_do(s, eid, CmdSaveDesign.TYPE, {"design": corvette.id, "name": "Changed", "hull": CORVETTE, "components": ["", "", ""]})
	assert_eq(b.components[0], AC)
	b.days_done = b.total_days - 1
	yard.stockpile.add("core:resource/alloys", 10000000)
	yard.stockpile.add("core:resource/components", 10000000)
	Shipyards.day_tick(s)
	var ships := s.units.values().filter(func(u: Unit) -> bool: return u.owner == eid and u.kind == "warship")
	assert_eq(ships.size(), 1, "launched")
	assert_eq((ships[0] as Unit).components[0], AC, "the ship carries the queued parts")
	assert_eq((ships[0] as Unit).design, corvette.id)


func test_design_survives_save_and_load() -> void:
	var s := _match()
	var eid := _human(s).id
	_do(s, eid, CmdSaveDesign.TYPE, {"name": "Keeper", "hull": CORVETTE, "components": [AC, "", ARMOR]})
	var back := MatchState.from_dict(s.to_dict())
	assert_eq(back.checksum(), s.checksum())
	var d: ShipDesign = back.designs.values().filter(func(x: ShipDesign) -> bool: return x.name == "Keeper")[0]
	assert_eq(d.components, [AC, "", ARMOR] as Array[String])


func test_export_code_round_trip() -> void:
	var code := DesignCode.encode("Hammer of Sol", CRUISER, [AC, RAIL, RAIL, ARMOR, SHIELD, "", ""])
	var back := DesignCode.decode(code, _db, "core:species/human")
	assert_eq(back["errors"], [])
	assert_eq(back["missing_mods"], [])
	assert_eq(back["name"], "Hammer of Sol")
	assert_eq(back["components"][1], RAIL)
	var wrong := DesignCode.decode(code, _db, "core:species/krothi")
	assert_eq(wrong["errors"].size(), 1, "wrong species is rejected")
	assert_eq(DesignCode.decode("not a code", _db, "core:species/human")["errors"].size(), 1)


func test_import_flags_missing_mod_content() -> void:
	var data := DesignCode.to_json_dict("Modded", CRUISER, ["coolmod:component/plasma_s", "", "", "", "", "", ""])
	assert_eq(data["mods_required"], ["coolmod"])
	var back := DesignCode.from_json_dict(data, _db, "core:species/human")
	assert_eq(back["missing_mods"], ["coolmod"])


func test_personal_library() -> void:
	var dir := "user://test_designs_%d" % Time.get_ticks_usec()
	assert_eq(DesignLibrary.save("Hammer of Sol!", CORVETTE, [AC, AC, ARMOR], dir), "")
	var items := DesignLibrary.list(dir)
	assert_eq(items.size(), 1)
	assert_eq(items[0]["file"], "hammer_of_sol_.json")
	assert_eq(items[0]["data"]["hull"], CORVETTE)
	DesignLibrary.remove(items[0]["file"], dir)
	assert_eq(DesignLibrary.list(dir).size(), 0)
	DirAccess.remove_absolute(dir)
