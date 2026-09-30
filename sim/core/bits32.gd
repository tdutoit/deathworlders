class_name Bits32
extends RefCounted
## Unsigned 32-bit helpers on GDScript's signed 64-bit int (M1 WP2).
## Inputs are masked to 32 bits; no intermediate reaches 2^48, so nothing can overflow.
## Must match tools/reference/rng_reference.py exactly.

const M32 := 0xFFFFFFFF


## (a * b) mod 2^32, split into 16-bit halves so the widest product stays below 2^48.
static func mul32(a: int, b: int) -> int:
	a &= M32
	b &= M32
	var lo := a * (b & 0xFFFF)
	var hi := (a * (b >> 16)) & 0xFFFF
	return (lo + (hi << 16)) & M32


## Rotate left by k (0..31). Bits that would leave the 32-bit window are masked off before shifting.
static func rotl32(x: int, k: int) -> int:
	x &= M32
	return ((x & (M32 >> k)) << k) | (x >> (32 - k))


## MurmurHash3 fmix32 finaliser.
static func mix32(z: int) -> int:
	z &= M32
	z ^= z >> 16
	z = mul32(z, 0x85EBCA6B)
	z ^= z >> 13
	z = mul32(z, 0xC2B2AE35)
	z ^= z >> 16
	return z
