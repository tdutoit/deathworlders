class_name DetRng
extends RefCounted
## Deterministic RNG: xoshiro128** on 32-bit values, seeded by splitmix32 (M1 WP2).
## Must reproduce tools/reference/vectors.json exactly. Only the sim advances these streams.

const GALAXY := "galaxy"
const COMBAT := "combat"
const EVENTS := "events"
const AI := "ai"
const MISC := "misc"

const M32 := Bits32.M32
const SPLITMIX_GAMMA := 0x9E3779B9

var _s0: int
var _s1: int
var _s2: int
var _s3: int


func _init(s0: int = 0, s1: int = 0, s2: int = 0, s3: int = 0) -> void:
	_set_words(s0, s1, s2, s3)


func _set_words(s0: int, s1: int, s2: int, s3: int) -> void:
	_s0 = s0 & M32
	_s1 = s1 & M32
	_s2 = s2 & M32
	_s3 = s3 & M32
	if _s0 == 0 and _s1 == 0 and _s2 == 0 and _s3 == 0:
		_s0 = 1  # xoshiro's all-zero state is a fixed point


## Named stream for a match: splitmix32 seeded with match_seed ^ fnv1a32(stream_name).
static func from_seed(match_seed: int, stream_name: String) -> DetRng:
	var sm := (match_seed & M32) ^ DetHash.fnv1a32_str(stream_name)
	var s: Array[int] = []
	for i in 4:
		sm = (sm + SPLITMIX_GAMMA) & M32
		s.append(Bits32.mix32(sm))
	return DetRng.new(s[0], s[1], s[2], s[3])


## Stream name reserved for a mod's own randomness.
static func mod_stream(mod_id: String) -> String:
	return "mod:" + mod_id


## Match seed from a typed seed string.
static func match_seed_from_text(text: String) -> int:
	return DetHash.fnv1a32_str(text)


func next_u32() -> int:
	var result := Bits32.rotl32((_s1 * 5) & M32, 7) * 9 & M32
	var t := (_s1 << 9) & M32
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = Bits32.rotl32(_s3, 11)
	return result


## Uniform int in [lo, hi). Rejection sampling, so there is no modulo bias.
func range(lo: int, hi: int) -> int:
	var n := hi - lo
	assert(n > 0 and n <= (1 << 32), "DetRng.range: need lo < hi and hi - lo <= 2^32")
	var limit := (1 << 32) - ((1 << 32) % n)
	while true:
		var r := next_u32()
		if r < limit:
			return lo + r % n
	return lo  # unreachable


## 0..999; a permille chance succeeds when roll_permille() < chance (Sub-spec A0).
func roll_permille() -> int:
	return self.range(0, FixedMath.PERMILLE)  # bare range() is the global builtin


func get_state() -> Array[int]:
	return [_s0, _s1, _s2, _s3]


func set_state(state: Array[int]) -> void:
	assert(state.size() == 4, "DetRng.set_state: expected 4 words")
	_set_words(state[0], state[1], state[2], state[3])
