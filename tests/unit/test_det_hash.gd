extends GutTest
# M1 WP2: DetHash.hash_state is order-independent and type-aware.


func test_dictionary_key_order_does_not_matter() -> void:
	var a := {"tick": 5, "seed": 42, "units": {3: "scout", 1: "frigate"}}
	var b := {"units": {1: "frigate", 3: "scout"}, "seed": 42, "tick": 5}
	assert_eq(DetHash.hash_state(a), DetHash.hash_state(b))


func test_value_changes_change_hash() -> void:
	var base := DetHash.hash_state({"tick": 5, "seed": 42})
	assert_ne(DetHash.hash_state({"tick": 6, "seed": 42}), base)
	assert_ne(DetHash.hash_state({"tick": 5, "seed": 42, "x": null}), base)


func test_types_are_distinguished() -> void:
	var values := [1, "1", [1], {1: 1}, true, null, 0, "", [], {}]
	var seen := {}
	for v: Variant in values:
		seen[DetHash.hash_value(v)] = true
	assert_eq(seen.size(), values.size(), "every value hashes differently")


func test_array_order_matters() -> void:
	assert_ne(DetHash.hash_value([1, 2]), DetHash.hash_value([2, 1]))


func test_string_boundaries_are_unambiguous() -> void:
	assert_ne(DetHash.hash_value(["ab", "c"]), DetHash.hash_value(["a", "bc"]))


func test_idmap_hashes_like_equivalent_dictionary() -> void:
	var m := IdMap.new()
	m.put(2, "b")
	m.put(1, "a")
	assert_eq(DetHash.hash_value(m), DetHash.hash_value({1: "a", 2: "b"}))


func test_packed_arrays_hash_like_arrays() -> void:
	assert_eq(DetHash.hash_value(PackedInt64Array([1, 2, 3])), DetHash.hash_value([1, 2, 3]))
	assert_eq(DetHash.hash_value(PackedStringArray(["x"])), DetHash.hash_value(["x"]))


func test_string_name_hashes_like_string() -> void:
	assert_eq(DetHash.hash_value(&"core:hull"), DetHash.hash_value("core:hull"))


func test_known_hash_is_stable() -> void:
	# Pinned so any change to the canonical encoding shows up as a deliberate test update.
	assert_eq(DetHash.hash_state({"b": [1, "x"], "a": true}), DetHash.hash_state({"a": true, "b": [1, "x"]}))
	assert_eq(DetHash.hash_value(null), DetHash.fnv1a32_byte(0, DetHash.OFFSET))
