extends GutTest
# M1 WP12: Blender pipeline proof. The core corvette HullDef references the skill-built .glb, the
# content validator checks its hardpoints, and the Solar view shows it with the empire tint.

const MODEL := "res://assets/models/ships/human_corvette_mk1.glb"


func test_glb_reader_finds_hardpoints_and_markers() -> void:
	var errors: Array[String] = []
	var names := GlbReader.node_names(MODEL, errors)
	assert_eq(errors, [] as Array[String])
	for n in ["HP_W_S_01", "HP_W_S_02", "HP_D_S_01", "ENGINE_01", "human_corvette_mk1_LOD0", "human_corvette_mk1_LOD1"]:
		assert_has(names, n)


func test_glb_reader_rejects_non_glb() -> void:
	var errors: Array[String] = []
	GlbReader.node_names("res://project.godot", errors)
	assert_eq(errors.size(), 1)


func test_core_hull_is_valid() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	assert_false(loader.report.has_errors(), loader.report.format_text())
	var hull: HullDef = loader.db.get_def(&"core:hull/human_corvette_mk1")
	assert_eq(hull.slots.size(), 3)
	assert_eq(hull.slots[2].slot_type, SlotDef.SlotType.DEFENCE)
	assert_eq(hull.hull, 270, "A2 300 x0.9 (M4 WP1 species balance)")
	assert_eq(hull.cost[&"core:resource/alloys"], 72, "60 x1.2 (M4 WP1)")


func test_bad_hulls_fail_readably() -> void:
	var loader := ContentLoader.new()
	loader.load_mods(["res://tests/fixtures/mods/bad_hull_mod"] as Array[String])
	var r := loader.report
	assert_true(r.has_error_containing(["bad_hull_mod", "no_such_hardpoint", "HP_W_M_01", "is not in"]), r.format_text())
	assert_true(r.has_error_containing(["wrong_letters", "HP_D_S_01", "does not match its slot"]), r.format_text())
	assert_true(r.has_error_containing(["missing_model", "nothing_here.glb", "not found"]), r.format_text())


func test_slots_round_trip_through_to_dict() -> void:
	var errors: Array[String] = []
	var hull := DefFactory.from_dict({"category": "hull", "id": "h", "name_key": "K", "species": "core:species/human",
			"hull_class": "corvette", "hull": 1,
			"slots": [{"slot_type": "core", "slot_size": "L", "hardpoint": "HP_C_L_01"}]}, "m", errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(hull.to_dict()["slots"], [{"slot_type": SlotDef.SlotType.CORE, "slot_size": SlotDef.SlotSize.L, "hardpoint": &"HP_C_L_01"}])


func test_solar_view_shows_tinted_model() -> void:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	assert_eq(GameState.start_new_match(settings, 99), [] as Array[String])
	var state := GameState.state
	var human: Empire = state.empires.get_or(GameState.first_human_empire())
	var home := state.galaxy.planet(human.capital_planet).system_id
	Sim.execute(state, [CommandRegistry.create(CmdDebugSpawnScout.TYPE, human.id, {"system": home})] as Array[Command])
	var view := SolarView.new()
	add_child_autofree(view)
	view.build(state, home)
	var unit_id: int = state.units.keys()[0]
	var node := view.get_node("Unit%d" % unit_id)
	var lod0 := node.find_child("human_corvette_mk1_LOD0", true, false) as MeshInstance3D
	assert_not_null(lod0, "the hull model is used, not the chevron")
	assert_true(lod0.visible)
	assert_false((node.find_child("human_corvette_mk1_LOD1", true, false) as MeshInstance3D).visible)
	var tinted := false
	for s in lod0.mesh.get_surface_count():
		var o := lod0.get_surface_override_material(s) as BaseMaterial3D
		if o != null and o.resource_name == "FACTION":
			var c := Color.html(human.color)
			assert_almost_eq(o.albedo_color.h, c.h, 0.01, "FACTION tinted with the empire hue")
			tinted = true
	assert_true(tinted, "FACTION surface overridden")
	GameState.end_match()


## M3 WP11: every human Mk I hull and every weapon component has a model, and hull slots name its hardpoints.
func test_human_hulls_and_turrets_have_models() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	for def in loader.db.defs("hull"):
		var h: HullDef = def
		if h.species != &"core:species/human" or h.role != &"warship":
			continue
		assert_ne(h.model, "", "%s has a model" % h.id)
		var errors: Array[String] = []
		var names := GlbReader.node_names("res://" + h.model, errors)
		for slot in h.slots:
			assert_has(names, String(slot.hardpoint), "%s: %s" % [h.id, slot.hardpoint])
	for def in loader.db.defs("component"):
		var c: ComponentDef = def
		if c.family != &"" and c.family != &"core:weapon_family/fighter":  # fighters launch from hangars
			assert_true(c.model != "" and ResourceLoader.exists("res://" + c.model), "%s has a turret model" % c.id)
