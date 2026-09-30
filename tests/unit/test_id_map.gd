extends GutTest
# M1 WP2: IdMap iterates in sorted key order regardless of insertion history.


func _collect(m: IdMap) -> Array:
	var out := []
	for key: Variant in m:
		out.append(key)
	return out


func test_int_keys_iterate_sorted() -> void:
	var m := IdMap.new()
	for k: int in [42, -3, 7, 1000, 0]:
		m.put(k, "v%d" % k)
	assert_eq(_collect(m), [-3, 0, 7, 42, 1000])
	assert_eq(m.keys(), [-3, 0, 7, 42, 1000])
	assert_eq(m.values(), ["v-3", "v0", "v7", "v42", "v1000"])


func test_string_keys_iterate_by_code_point() -> void:
	var m := IdMap.new()
	for k: String in ["core:hull/b", "Zeta", "core:hull/a", "alpha"]:
		m.put(k, true)
	assert_eq(_collect(m), ["Zeta", "alpha", "core:hull/a", "core:hull/b"])


func test_insertion_order_does_not_matter() -> void:
	var a := IdMap.new()
	var b := IdMap.new()
	for k: int in [5, 1, 9, 3]:
		a.put(k, k * 10)
	for k: int in [9, 3, 1, 5]:
		b.put(k, k * 10)
	assert_eq(a.keys(), b.keys())
	assert_eq(a.values(), b.values())
	assert_eq(DetHash.hash_value(a), DetHash.hash_value(b))


func test_put_get_has_erase() -> void:
	var m := IdMap.new()
	m.put(2, "two")
	m.put(1, "one")
	m.put(2, "TWO")
	assert_eq(m.size(), 2)
	assert_eq(m.get_or(2), "TWO")
	assert_eq(m.get_or(3, "none"), "none")
	assert_true(m.has(1))
	assert_true(m.erase(1))
	assert_false(m.erase(1))
	assert_false(m.has(1))
	assert_eq(m.keys(), [2])
	m.put(0, "zero")
	assert_eq(m.keys(), [0, 2], "re-sorted after insert following erase")


func test_keys_returns_copy() -> void:
	var m := IdMap.new()
	m.put(1, 1)
	var keys := m.keys()
	keys.append(99)
	assert_eq(m.keys(), [1])


func test_empty_and_clear() -> void:
	var m := IdMap.new()
	assert_true(m.is_empty())
	assert_eq(_collect(m), [])
	m.put("a", 1)
	m.clear()
	assert_true(m.is_empty())
	assert_eq(_collect(m), [])
	m.put(5, 1)  # key type may change once the map is empty again
	assert_eq(m.keys(), [5])


func test_nested_iteration() -> void:
	var m := IdMap.new()
	for k: int in [2, 1]:
		m.put(k, k)
	var pairs := []
	for a: Variant in m:
		for b: Variant in m:
			pairs.append([a, b])
	assert_eq(pairs, [[1, 1], [1, 2], [2, 1], [2, 2]])
