class_name DetHash
extends RefCounted
## Stable FNV-1a 32-bit hashing for anything persisted or networked (M1 WP2).
## Never use Godot's hash(): it isn't guaranteed stable across engine versions.
## fnv1a32_* must match tools/reference/vectors.json exactly.

const OFFSET := 0x811C9DC5
const PRIME := 0x01000193
const M32 := Bits32.M32

# Type tags for hash_value, so e.g. 1, "1" and [1] hash differently.
const _TAG_NIL := 0
const _TAG_BOOL := 1
const _TAG_INT := 2
const _TAG_STRING := 3
const _TAG_ARRAY := 4
const _TAG_MAP := 5


static func fnv1a32_byte(b: int, h: int) -> int:
	return ((h ^ (b & 0xFF)) * PRIME) & M32


static func fnv1a32_bytes(data: PackedByteArray, h: int = OFFSET) -> int:
	for b in data:
		h = ((h ^ b) * PRIME) & M32
	return h


static func fnv1a32_str(s: String, h: int = OFFSET) -> int:
	return fnv1a32_bytes(s.to_utf8_buffer(), h)


## Signed 64-bit int hashed as 8 little-endian two's-complement bytes.
static func fnv1a32_int(v: int, h: int = OFFSET) -> int:
	for i in 8:
		h = ((h ^ ((v >> (8 * i)) & 0xFF)) * PRIME) & M32
	return h


## Hash of a whole state tree; dictionary keys are walked in sorted order.
static func hash_state(state: Dictionary) -> int:
	return hash_value(state)


## Canonical hash of null, bool, int, String/StringName, arrays (incl. packed int/string arrays),
## Dictionary and IdMap. A Dictionary and an IdMap with the same entries hash the same.
## Floats and other objects are rejected: they must never be part of sim state.
static func hash_value(value: Variant, h: int = OFFSET) -> int:
	match typeof(value):
		TYPE_NIL:
			return fnv1a32_byte(_TAG_NIL, h)
		TYPE_BOOL:
			return fnv1a32_byte(1 if value else 0, fnv1a32_byte(_TAG_BOOL, h))
		TYPE_INT:
			return fnv1a32_int(value, fnv1a32_byte(_TAG_INT, h))
		TYPE_STRING, TYPE_STRING_NAME:
			var bytes: PackedByteArray = String(value).to_utf8_buffer()
			h = fnv1a32_int(bytes.size(), fnv1a32_byte(_TAG_STRING, h))
			return fnv1a32_bytes(bytes, h)
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
				TYPE_PACKED_STRING_ARRAY:
			h = fnv1a32_int(value.size(), fnv1a32_byte(_TAG_ARRAY, h))
			for item: Variant in value:
				h = hash_value(item, h)
			return h
		TYPE_DICTIONARY:
			var d: Dictionary = value
			h = fnv1a32_int(d.size(), fnv1a32_byte(_TAG_MAP, h))
			for key: Variant in IdMap.sort_keys(d.keys()):
				h = hash_value(d[key], hash_value(key, h))
			return h
		TYPE_OBJECT:
			if value is IdMap:
				var m: IdMap = value
				h = fnv1a32_int(m.size(), fnv1a32_byte(_TAG_MAP, h))
				for key: Variant in m:
					h = hash_value(m.get_or(key), hash_value(key, h))
				return h
	push_error("DetHash.hash_value: unsupported type %s" % type_string(typeof(value)))
	assert(false, "DetHash.hash_value: floats and non-IdMap objects are not hashable sim state")
	return h
