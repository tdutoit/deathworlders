extends GutTest
# M3 WP1: combat content (Sub-spec A2, A9, B10, C3, C5) and the schema additions it needs.

const SPECIES := ["human", "krothi", "ohlan", "thessari", "vesskar"]
const CLASSES := ["corvette", "frigate", "destroyer", "cruiser", "battlecruiser", "battleship", "carrier", "assault"]

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _hull(sp: String, cls: String) -> HullDef:
	return _db.get_def(StringName("core:hull/%s_%s_mk1" % [sp, cls]))


func _comp(id: String) -> ComponentDef:
	return _db.get_def(StringName("core:component/" + id))


func test_counts() -> void:
	assert_eq(_db.ids("weapon_family").size(), 4)
	assert_eq(_db.ids("component").size(), 13)
	assert_eq(_db.ids("design").size(), 5 * 8 + 3, "a standard design per species and class + platform + 2 pirates")
	assert_eq(_db.ids("combat_rules").size(), 1)


func test_every_species_has_every_class_and_a_standard_design() -> void:
	for sp in SPECIES:
		for cls in CLASSES:
			var h := _hull(sp, cls)
			assert_not_null(h, "%s %s" % [sp, cls])
			if h == null:
				continue
			assert_eq(h.role, &"warship")
			assert_eq(String(h.species), "core:species/" + sp)
			var d: DesignDef = _db.get_def(StringName("core:design/%s_%s_standard" % [sp, cls]))
			assert_not_null(d)
			assert_eq(DesignDef.check_fit(h, d.components, _db), [] as Array[String], "%s %s design fits" % [sp, cls])


func test_human_hulls_match_a2_and_b10() -> void:
	var c := _hull("human", "cruiser")
	assert_eq([c.hull, c.armor, c.shield, c.evasion, c.speed], [1500, 60, 200, 80, 5])
	assert_eq(c.size, &"M")
	assert_eq(c.shipyard_size, &"M")
	assert_eq(c.cost[&"core:resource/alloys"], 260)
	assert_eq(c.cost[&"core:resource/rare_earths"], 10)
	assert_eq(c.build_days, 120)
	assert_eq(c.credit_upkeep_milli, 4000)
	assert_eq(c.slots.size(), 7, "1S 2M · 2D · 1U · 1C")
	var bb := _hull("human", "battleship")
	assert_eq([bb.hull, bb.armor, bb.shield, bb.size, bb.shipyard_size], [4000, 150, 800, &"XL", &"L"])
	assert_eq(_hull("human", "frigate").credit_upkeep_milli, 1500, "B10's 1.5 credits")


func test_species_variations() -> void:
	var human := _hull("human", "cruiser")
	var vess := _hull("vesskar", "cruiser")
	assert_eq(vess.shield, human.shield * 1400 / 1000, "Vess'kar shields +40%")
	assert_eq(vess.hull, human.hull * 750 / 1000, "Vess'kar hull -25%")
	var krothi := _hull("krothi", "cruiser")
	assert_eq(krothi.hull, human.hull * 800 / 1000, "Krothi hull -20%")
	assert_eq(krothi.cost[&"core:resource/alloys"], 260 * 650 / 1000, "Krothi cost -35%")
	assert_eq(_hull("thessari", "cruiser").armor, human.armor * 1300 / 1000, "Thessari armour +30%")
	assert_eq(_hull("thessari", "cruiser").speed, human.speed - 1)
	assert_eq(_hull("ohlan", "cruiser").evasion, human.evasion + 100, "Ohlan evasion +100")


func test_weapons_match_a2_and_families_a9() -> void:
	var rail := _comp("railgun_m")
	assert_eq([rail.damage, rail.shots, rail.penetration], [100, 1, 30])
	assert_eq(rail.accuracy, [400, 750, 800] as Array[int])
	var energy: WeaponFamilyDef = _db.get_def(&"core:weapon_family/energy")
	assert_eq([energy.shield_mult, energy.armor_eff], [700, 500])
	var missile: WeaponFamilyDef = _db.get_def(&"core:weapon_family/missile")
	assert_true(missile.interceptable and missile.uses_ammo and missile.ecm_affected)
	assert_eq(_comp("torpedo_l").ammo_per_shot, 1)
	assert_has(_comp("torpedo_l").tags, &"ignores_screening", "A6: torpedoes and fighters ignore screening")
	assert_has(_comp("fighter_wing").tags, &"ignores_screening")


func test_components_fit_same_type_and_smaller_or_equal_size() -> void:
	var cruiser := _hull("human", "cruiser")  # slots: W_S, W_M, W_M, D_M, D_M, U_S, C_M
	assert_true(_comp("autocannon_s").fits(cruiser.slots[0]))
	assert_true(_comp("autocannon_s").fits(cruiser.slots[1]), "a small weapon fits a medium slot")
	assert_false(_comp("railgun_m").fits(cruiser.slots[0]), "a medium weapon doesn't fit a small slot")
	assert_false(_comp("railgun_m").fits(cruiser.slots[3]), "weapons don't go in defence slots")
	assert_true(_comp("armor_plate").fits(cruiser.slots[3]))
	var errors := DesignDef.check_fit(cruiser, ["core:component/railgun_m", "", "", "", "", "", ""], _db)
	assert_eq(errors.size(), 1, "railgun in the small slot is reported")
	assert_eq(DesignDef.check_fit(cruiser, ["", ""], _db).size(), 1, "wrong slot count is reported")


func test_platform_station_and_pirates() -> void:
	var st: StationDef = _db.get_def(&"core:station/defence_platform_t1")
	assert_eq(st.function, &"defence")
	assert_eq(st.security, 10)
	assert_eq(st.cost[&"core:resource/alloys"], 150, "B10")
	assert_eq(st.build_days, 90)
	var rules: CombatRulesDef = _db.get_def(CombatRulesDef.ID)
	var raider: DesignDef = _db.get_def(rules.pirate_raider_design)
	assert_eq((_db.get_def(raider.hull) as HullDef).role, &"raider")
	assert_eq((_db.get_def((_db.get_def(rules.pirate_base_design) as DesignDef).hull) as HullDef).role, &"platform")


func test_combat_rules_hold_sub_spec_a_numbers() -> void:
	var r: CombatRulesDef = _db.get_def(CombatRulesDef.ID)
	assert_eq([r.hit_min, r.hit_max, r.armor_k, r.pd_intercept, r.round_cap], [50, 950, 100, 450, 48])
	assert_eq(r.crew_by_size[&"XL"], 120)
	assert_eq(r.ammo_per_weapon, 20)


func test_json_components_and_designs() -> void:
	var errors: Array[String] = []
	var c := DefFactory.from_dict({"category": "component", "id": "test_gun", "name_key": "X", "slot_type": "weapon",
		"slot_size": "S", "family": "weapon_family/kinetic", "damage": 10, "shots": 1, "accuracy": [100, 200, 300]},
		"testmod", errors)
	assert_eq(errors, [] as Array[String])
	assert_eq((c as ComponentDef).accuracy, [100, 200, 300] as Array[int], "int_list from JSON")
	errors.clear()
	DefFactory.from_dict({"category": "component", "id": "bad", "name_key": "X", "slot_type": "weapon",
		"slot_size": "S", "accuracy": [1, 2.5, 3]}, "testmod", errors)
	assert_gt(errors.size(), 0, "fractional numbers are rejected")
	errors.clear()
	var d := DefFactory.from_dict({"category": "design", "id": "d", "name_key": "X", "hull": "core:hull/human_corvette_mk1",
		"components": ["core:component/autocannon_s", "", "core:component/armor_plate"]}, "testmod", errors)
	assert_eq(errors, [] as Array[String])
	assert_eq((d as DesignDef).components[1], &"", "\"\" is an empty slot")
	assert_eq(DefFactory.check(d, _db, {}), [] as Array[String], "empty slots pass the reference check")
	var short := ComponentDef.new()
	short.accuracy = [1, 2] as Array[int]
	var errs: Array[String] = []
	DefFactory._check_field(short.accuracy, {"type": "int_list", "size": 3}, _db, {}, "accuracy", errs)
	assert_eq(errs.size(), 1, "int_list size is checked")
