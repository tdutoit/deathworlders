extends GutTest
# M1 WP3: loading core plus the fixture mods in tests/fixtures/mods/ (Sub-spec C6, C10).

const FIXTURES := "res://tests/fixtures/mods/"


func _load(mod_names: Array = []) -> ContentLoader:
	var dirs: Array[String] = []
	for n: String in mod_names:
		dirs.append(FIXTURES + n)
	var loader := ContentLoader.new()
	loader.load_mods(dirs)
	return loader


func _report(loader: ContentLoader) -> String:
	return loader.report.format_text()


# --- core ---

func test_core_loads_cleanly() -> void:
	var l := _load()
	assert_eq(l.report.entries, [] as Array[Dictionary], _report(l))
	assert_eq(l.report.load_order, ["core"] as Array[String])
	assert_true(l.db.is_frozen())


func test_core_counts() -> void:
	var db := _load().db
	assert_eq(db.ids("resource").size(), 11)
	assert_eq(db.ids("planet_type").size(), 9)
	assert_eq(db.ids("star_type").size(), 6)
	assert_eq(db.ids("species").size(), 5)
	assert_eq(db.ids("match_preset").size(), 7)
	assert_eq(db.ids("modifier_key").size(), 21, "15 + 6 ship keys (M3 WP1)")


func test_core_values() -> void:
	var db := _load().db
	var fuel: ResourceDef = db.get_def(&"core:resource/fuel")
	assert_eq(fuel.base_value, 1500)
	assert_true(fuel.physical)
	var credits: ResourceDef = db.get_def(&"core:resource/credits")
	assert_false(credits.physical)
	assert_eq(credits.stockpile_default_cap, 0)
	var human: SpeciesDef = db.get_def(&"core:species/human")
	assert_eq(human.home_template, &"sol")
	assert_eq(human.habitability[&"core:planet_type/deathworld"], 1000)
	assert_eq(human.source_mod, &"core")
	var pace: MatchPresetDef = db.get_def(&"core:match_preset/pace_epic")
	assert_eq(pace.pace_permille, 1600)


func test_dense_indices_follow_sorted_ids() -> void:
	var db := _load().db
	var ids := db.ids("resource")
	assert_eq(ids, IdMap.sort_keys(ids))
	for i in ids.size():
		assert_eq(db.index_of(StringName(ids[i])), i)
		assert_eq(db.id_at("resource", i), StringName(ids[i]))
	assert_eq(db.index_of(&"core:resource/nope"), -1)


func test_content_hash_stable_across_loads() -> void:
	assert_eq(_load().db.content_hash, _load().db.content_hash)
	assert_ne(_load().db.content_hash, DetHash.OFFSET, "hash covers something")


func test_core_tres_cache_is_not_mutated_by_patches() -> void:
	_load(["patch_mod"])
	var fuel: ResourceDef = _load().db.get_def(&"core:resource/fuel")
	assert_eq(fuel.base_value, 1500, "a later load must not see an earlier load's patches")


# --- ops ---

func test_add_mod() -> void:
	var l := _load(["add_mod"])
	assert_false(l.report.has_errors(), _report(l))
	assert_eq(l.report.load_order, ["core", "add_mod"] as Array[String])
	var plasma: ResourceDef = l.db.get_def(&"add_mod:resource/plasma")
	assert_eq(plasma.base_value, 12000)
	assert_eq(plasma.source_mod, &"add_mod")
	assert_eq(plasma.source_file, "defs/resources.json")
	var lava: PlanetTypeDef = l.db.get_def(&"add_mod:planet_type/lava")
	assert_not_null(lava, "Def in a subfolder")
	assert_eq(lava.modifiers.size(), 2)
	assert_eq(lava.modifiers[1].mode, ModifierDef.Mode.PERMILLE)
	assert_eq(l.db.ids("resource").size(), 12)


func test_patch_mod() -> void:
	var l := _load(["patch_mod"])
	assert_false(l.report.has_errors(), _report(l))
	var fuel: ResourceDef = l.db.get_def(&"core:resource/fuel")
	assert_eq(fuel.base_value, 1800, "set")
	assert_eq(fuel.tags, [&"volatile"] as Array[StringName], "add")
	assert_eq(fuel.stockpile_default_cap, 600, "adjust")
	var human: SpeciesDef = l.db.get_def(&"core:species/human")
	assert_eq(human.habitability[&"core:planet_type/toxic"], 500, "adjust map entry")
	assert_false(human.habitability.has(&"core:planet_type/barren"), "remove map entry")
	assert_eq(human.modifiers.size(), 1, "add modifier")


func test_patch_changes_content_hash() -> void:
	assert_ne(_load(["patch_mod"]).db.content_hash, _load().db.content_hash)


func test_cosmetic_mod_does_not_change_content_hash() -> void:
	var l := _load(["cosmetic_mod"])
	assert_false(l.report.has_errors(), _report(l))
	assert_true(l.db.has(&"cosmetic_mod:star_type/pink"))
	assert_eq(l.db.content_hash, _load().db.content_hash)


func test_override_mod() -> void:
	var l := _load(["override_mod"])
	assert_false(l.report.has_errors(), _report(l))
	var neutron: StarTypeDef = l.db.get_def(&"core:star_type/neutron")
	assert_eq(neutron.weight, 1)
	assert_eq(neutron.color, "#ffffff")
	assert_eq(neutron.source_mod, &"override_mod")


# --- validation errors ---

func test_broken_reference_fails_readably() -> void:
	var l := _load(["broken_ref_mod"])
	assert_true(l.report.has_errors())
	assert_true(l.report.has_error_containing(["broken_ref_mod", "defs/species.json",
			"home_planet_type", "core:planet_type/lava", "does not exist"]), _report(l))
	assert_true(l.report.has_error_containing(["habitability", "core:planet_type/swamp"]), _report(l))


func test_fractional_number_rejected() -> void:
	var l := _load(["fraction_mod"])
	assert_true(l.report.has_error_containing(["fraction_mod", "base_value", "not a whole number"]), _report(l))
	assert_false(l.db.has(&"fraction_mod:resource/half"))


func test_new_ids_need_own_prefix() -> void:
	var l := _load(["prefix_mod"])
	assert_true(l.report.has_error_containing(["prefix_mod", "core:resource/stolen", "prefix"]), _report(l))
	assert_false(l.db.has(&"core:resource/stolen"))


func test_unknown_field_rejected() -> void:
	var l := _load(["unknown_field_mod"])
	assert_true(l.report.has_error_containing(["unknown_field_mod", "unknown field 'base_valu'"]), _report(l))


func test_tres_needs_script_mod() -> void:
	var data := _load(["tres_data_mod"])
	assert_true(data.report.has_error_containing(["tres_data_mod", "goo.tres", "data-only mods must use .json"]), _report(data))
	assert_false(data.db.has(&"tres_data_mod:resource/goo"))
	var script := _load(["tres_script_mod"])
	assert_false(script.report.has_errors(), _report(script))
	assert_true(script.db.has(&"tres_script_mod:resource/goo"))


# --- load order ---

func test_dependency_order_beats_alphabetical() -> void:
	var l := _load(["aaa_child", "zzz_parent"])
	assert_false(l.report.has_errors(), _report(l))
	assert_eq(l.report.load_order, ["core", "zzz_parent", "aaa_child"] as Array[String])
	var ore: ResourceDef = l.db.get_def(&"core:resource/ore")
	assert_eq(ore.base_value, 1200, "the dependent mod loads later, so its set wins")
	assert_eq(l.report.warnings().size(), 1, "set conflict is reported")
	assert_string_contains(ContentReport.format_entry(l.report.warnings()[0]), "zzz_parent")


func test_load_before_hint() -> void:
	var l := _load(["aaa_hint", "bbb_hint"])
	assert_eq(l.report.load_order, ["core", "bbb_hint", "aaa_hint"] as Array[String])


func test_alphabetical_tie_break() -> void:
	var l := _load(["patch_mod", "add_mod", "override_mod"])
	assert_false(l.report.has_errors(), _report(l))
	assert_eq(l.report.load_order, ["core", "add_mod", "override_mod", "patch_mod"] as Array[String])


func test_dependency_cycle_reported() -> void:
	var l := _load(["cycle_a", "cycle_b", "add_mod"])
	assert_true(l.report.has_error_containing(["cycle_a", "cycle"]), _report(l))
	assert_true(l.report.has_error_containing(["cycle_b", "cycle"]), _report(l))
	assert_eq(l.report.load_order, ["core", "add_mod"] as Array[String], "other mods still load")


func test_missing_and_wrong_version_dependencies() -> void:
	var l := _load(["missing_dep_mod", "old_dep_mod", "zzz_parent"])
	assert_true(l.report.has_error_containing(["missing_dep_mod", "missing dependency 'no_such_mod'"]), _report(l))
	assert_true(l.report.has_error_containing(["old_dep_mod", "zzz_parent", ">=2.0.0"]), _report(l))
	assert_eq(l.report.load_order, ["core", "zzz_parent"] as Array[String])


# --- autoload ---

func test_database_autoload_has_core() -> void:
	assert_not_null(Database.defs)
	assert_false(Database.report.has_errors(), Database.report.format_text())
	assert_true(Database.defs.has(&"core:species/human"))
