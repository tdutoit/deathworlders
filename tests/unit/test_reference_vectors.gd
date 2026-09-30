extends GutTest
# M1 WP2: GDScript Bits32/DetHash/DetRng must reproduce tools/reference/vectors.json exactly.

const VECTORS_PATH := "res://tools/reference/vectors.json"

var _v: Dictionary


func before_all() -> void:
	_v = JSON.parse_string(FileAccess.get_file_as_string(VECTORS_PATH))


# JSON numbers arrive as floats; every vector value is < 2^53, so int() is exact.
func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for x: Variant in values:
		out.append(int(x))
	return out


func test_vectors_loaded() -> void:
	assert_false(_v.is_empty(), "could not read " + VECTORS_PATH)


func test_fnv1a32_str() -> void:
	for s: String in _v["fnv1a32"]:
		assert_eq(DetHash.fnv1a32_str(s), int(_v["fnv1a32"][s]), "fnv1a32 '%s'" % s)


func test_fnv1a32_int() -> void:
	for k: String in _v["fnv1a32_int"]:
		assert_eq(DetHash.fnv1a32_int(k.to_int()), int(_v["fnv1a32_int"][k]), "fnv1a32_int " + k)


func test_mul32() -> void:
	for m: Dictionary in _v["mul32"]:
		assert_eq(Bits32.mul32(int(m["a"]), int(m["b"])), int(m["result"]))


func test_mix32() -> void:
	for k: String in _v["mix32"]:
		assert_eq(Bits32.mix32(k.to_int()), int(_v["mix32"][k]), "mix32 " + k)


func test_match_seed_from_text() -> void:
	for t: String in _v["match_seed_from_text"]:
		assert_eq(DetRng.match_seed_from_text(t), int(_v["match_seed_from_text"][t]), t)


func test_xoshiro_streams() -> void:
	for key: String in _v["xoshiro128ss"]:
		var parts := key.split(":")
		var rng := DetRng.from_seed(parts[0].to_int(), parts[1])
		var expected: Dictionary = _v["xoshiro128ss"][key]
		assert_eq(rng.get_state(), _ints(expected["initial_state"]), key + " initial state")
		var got: Array[int] = []
		for i in 10:
			got.append(rng.next_u32())
		assert_eq(got, _ints(expected["first_10"]), key + " first 10")


func test_range_sequence() -> void:
	var rng := DetRng.from_seed(7, DetRng.COMBAT)
	var a: Array[int] = []
	for i in 10:
		a.append(rng.range(0, 1000))
	assert_eq(a, _ints(_v["range"]["7:combat range(0,1000) x10"]))
	var b: Array[int] = []
	for i in 5:
		b.append(rng.range(850, 1151))
	assert_eq(b, _ints(_v["range"]["then range(850,1151) x5"]))
