extends GutTest
# M1 WP3: ID rules, version constraints and DefFactory conversion/patch details.


func test_def_ids() -> void:
	assert_true(DefIds.is_full("core:hull/human_cruiser_mk1"))
	assert_true(DefIds.is_full("core:modifier_key/planet.housing"))
	assert_false(DefIds.is_full("Core:hull/x"))
	assert_false(DefIds.is_full("core:hull"))
	assert_eq(DefIds.resolve_ref("planet_type/terran", "my_mod"), "my_mod:planet_type/terran")
	assert_eq(DefIds.resolve_ref("core:planet_type/terran", "my_mod"), "core:planet_type/terran")
	assert_eq(DefIds.resolve_ref("terran", "my_mod"), "", "bare names are not references")
	assert_eq(DefIds.resolve_own("terran", "my_mod", "planet_type"), "my_mod:planet_type/terran")
	assert_eq(DefIds.mod_of("core:hull/x"), "core")
	assert_eq(DefIds.category_of("core:hull/x"), "hull")


func test_semver() -> void:
	assert_eq(Semver.parse("1.2.3"), [1, 2, 3] as Array[int])
	assert_eq(Semver.parse("1.2"), [] as Array[int])
	assert_true(Semver.satisfies("1.2.0", ">=1.0.0 <2.0.0"))
	assert_false(Semver.satisfies("2.0.0", ">=1.0.0 <2.0.0"))
	assert_true(Semver.satisfies("0.1.0", ""))
	assert_true(Semver.satisfies("1.0.0", "1.0.0"))
	assert_false(Semver.satisfies("1.0.1", "=1.0.0"))
	assert_true(Semver.satisfies("1.10.0", ">1.9.0"), "numeric, not string, comparison")
	assert_false(Semver.is_valid_constraint(">=one"))


func test_from_dict_type_errors() -> void:
	var errors: Array[String] = []
	var def := DefFactory.from_dict({"category": "resource", "id": "x", "name_key": "K", "base_value": "ten"}, "m", errors)
	assert_null(def)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "m:resource/x.base_value")


func test_from_dict_unknown_category() -> void:
	var errors: Array[String] = []
	assert_null(DefFactory.from_dict({"category": "dragon", "id": "x"}, "m", errors))
	assert_string_contains(errors[0], "unknown category 'dragon'")


func test_patch_rejects_bad_ops() -> void:
	var errors: Array[String] = []
	var def := DefFactory.from_dict({"category": "resource", "id": "x", "name_key": "K"}, "m", errors)
	DefFactory.apply_patch(def, {"multiply": {"base_value": 2}}, "m", errors)
	DefFactory.apply_patch(def, {"add": {"base_value": 2}}, "m", errors)
	DefFactory.apply_patch(def, {"adjust": {"name_key": 1}}, "m", errors)
	assert_eq(errors.size(), 3, "\n".join(errors))


func test_to_dict_is_hashable() -> void:
	var errors: Array[String] = []
	var def := DefFactory.from_dict({"category": "species", "id": "s", "name_key": "K", "color": "#000000",
			"home_template": "standard", "home_planet_type": "core:planet_type/terran",
			"habitability": {"core:planet_type/terran": 1000},
			"modifiers": [{"key": "planet.housing", "value": 5}]}, "m", errors)
	assert_eq(errors, [] as Array[String])
	var d := def.to_dict()
	assert_eq(d["id"], &"m:species/s")
	assert_eq(d["modifiers"][0]["key"], &"planet.housing")
	assert_ne(DetHash.hash_value(d), 0)
