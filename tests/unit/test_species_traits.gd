extends GutTest
# M4 WP1: species content and trait effects (main spec 10.1-10.3, A10, A12, A13, E2, E11).

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _design(id: String) -> Array:
	var d: DesignDef = _db.get_def(StringName(id))
	return [String(d.hull), Array(d.components).map(func(c: StringName) -> String: return String(c))]


func test_species_content() -> void:
	for name in ["human", "vesskar", "krothi", "ohlan", "thessari"]:
		var sp: SpeciesDef = _db.get_def(StringName("core:species/" + name))
		assert_gte(sp.traits.size(), 2, name)
		assert_eq(sp.ai_personality.size(), 7, "%s: all E11 weights" % name)
		assert_eq(sp.affinity.size(), 5, "%s: E2 row" % name)
		assert_ne(sp.signature_mechanic, &"", name)
	var vesskar: SpeciesDef = _db.get_def(&"core:species/vesskar")
	assert_eq(int(vesskar.affinity[&"core:species/human"]), -20, "the HFY arc in one number (E2)")
	assert_eq(int((_db.get_def(&"core:species/krothi") as SpeciesDef).ai_personality[&"aggression"]), 80)


func test_ship_traits_follow_the_owner_species() -> void:
	var d := _design("core:design/human_cruiser_standard")
	var plain := ShipStats.of(_db, d[0], d[1])
	var human := ShipStats.of(_db, d[0], d[1], "core:species/human")
	assert_eq(human.hull, FixedMath.mul_permille(plain.hull, 1100), "Deathworlder +10% hull")
	assert_eq(int(human.damage[&"core:weapon_family/kinetic"]), 100, "Kinetic Doctrine")
	var thessari := ShipStats.of(_db, d[0], d[1], "core:species/thessari")
	assert_eq(thessari.shield, FixedMath.mul_permille(plain.shield, 1150), "Shield Masters")
	assert_eq(thessari.hull, plain.hull, "Steadfast Defenders is for platforms only")


func test_class_conditions() -> void:
	var corvette := _design("core:design/krothi_corvette_standard")
	var cruiser := _design("core:design/krothi_cruiser_standard")
	var kc := ShipStats.of(_db, corvette[0], corvette[1], "core:species/krothi")
	var kr := ShipStats.of(_db, cruiser[0], cruiser[1], "core:species/krothi")
	assert_eq(int(kc.accuracy[kc.weapons[0].family]), 100, "Swarm Doctrine: corvettes")
	assert_eq(int(kr.accuracy[kr.weapons[0].family]), 0, "not cruisers")
	var platform := _design("core:design/defence_platform")
	var tp := ShipStats.of(_db, platform[0], platform[1], "core:species/thessari")
	var hp := ShipStats.of(_db, platform[0], platform[1], "")
	assert_eq(tp.hull, FixedMath.mul_permille(hp.hull, 1200), "Steadfast Defenders")


func test_ohlan_and_vesskar_weapons() -> void:
	var o := _design("core:design/ohlan_cruiser_standard")
	var os := ShipStats.of(_db, o[0], o[1], "core:species/ohlan")
	assert_true(os.weapons.any(func(w: ComponentDef) -> bool: return w.family == &"core:weapon_family/missile"), "missile bias")
	assert_eq(int(os.accuracy[&"core:weapon_family/missile"]), 100)
	assert_eq(os.ecm_strength, 50)
	var v := _design("core:design/vesskar_cruiser_standard")
	var vs := ShipStats.of(_db, v[0], v[1], "core:species/vesskar")
	assert_eq(int(vs.damage[&"core:weapon_family/energy"]), 100, "Ancient Science")
	assert_gt(vs.weapons.filter(func(w: ComponentDef) -> bool: return w.family == &"core:weapon_family/energy").size(), vs.weapons.size() / 2,
		"energy bias")


func _match(species: String) -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/" + species, "human")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func test_planet_traits_of_the_main_species() -> void:
	var s := _match("krothi")
	var e: Empire = s.empires.values()[0]
	var c := s.colony(e.capital_planet)
	var mods := PlanetMods.of(c, _db)
	assert_eq(mods.permille("planet.growth"), 500, "Ravenous")
	assert_eq(mods.permille("planet.food_upkeep"), 250)
	var v := _match("vesskar")
	var vc := v.colony((v.empires.values()[0] as Empire).capital_planet)
	assert_eq(PlanetMods.of(vc, _db).add("planet.stability"), 5, "Long-Lived")
	assert_eq(SpeciesTraits.dominant(vc), "core:species/vesskar")


func test_empire_traits() -> void:
	var s := _match("human")
	var eid: int = s.empires.keys()[0]
	assert_eq(SpeciesTraits.empire_add(s, eid, "empire.morale_resist"), 300, "Stubborn")
	assert_eq(SpeciesTraits.empire_add(s, eid, "empire.last_stand"), 1)
	assert_eq(SpeciesTraits.empire_add(s, eid, "empire.pursuit_rounds"), 1, "Persistence Hunters")
	assert_eq(SpeciesTraits.empire_permille(s, eid, "empire.salvage"), 500, "Improvisers")
	assert_eq(SpeciesTraits.empire_add(s, -1, "empire.morale_resist"), 0, "pirates have no species")


## A10 Last Stand: a badly outnumbered human formation holds at morale 100 for a few rounds.
func test_last_stand() -> void:
	var s := _match("human")
	var eid: int = s.empires.keys()[0]
	var home := s.galaxy.planet((s.empires.values()[0] as Empire).capital_planet).system_id
	var d := _design("core:design/human_corvette_standard")
	var u := Shipyards.spawn(s, eid, d[0], home)
	u.components.assign(d[1])
	Fleets.arm(s, u)
	var f := Fleets.create(s, eid, [u.id])
	f.retreat_at = 0
	for i in 6:
		Pirates.spawn_raider(s, home, eid)
	var saw := false
	for h in 40:
		s.clear_scratch()
		Battles.tick(s)
		for b: Battle in s.battles.values():
			for ev: Array in b.log["events"]:
				if ev[1] == "last_stand":
					saw = true
		for rep: BattleReport in s.reports.values():
			for ev: Array in rep.data["events"]:
				if ev[1] == "last_stand":
					saw = true
	assert_true(saw, "Last Stand triggered")
