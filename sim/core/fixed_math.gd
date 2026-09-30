class_name FixedMath
extends RefCounted
## Integer maths for the sim (M1 WP2). Fractions are permille: 1000 = 100% (Sub-spec A0).
##
## Overflow: GDScript ints are signed 64-bit. Callers keep every intermediate product below 2^62:
## - mul_permille / lerp_permille: |a * p| < 2^62 (e.g. |a| < 2^50 with p up to 4000).
## - dist2: |dx| and |dy| below 2^30.
## - isqrt: n below 2^62.

const PERMILLE := 1000


## Division rounding toward negative infinity (GDScript's `/` truncates toward zero).
static func floor_div(a: int, b: int) -> int:
	assert(b != 0, "FixedMath.floor_div: division by zero")
	@warning_ignore("integer_division")
	var q := a / b
	if a % b != 0 and ((a < 0) != (b < 0)):
		q -= 1
	return q


## Division rounding to nearest; exact halves round away from zero (2.5 -> 3, -2.5 -> -3).
static func div_round(a: int, b: int) -> int:
	assert(b != 0, "FixedMath.div_round: division by zero")
	var n := absi(a)
	var d := absi(b)
	@warning_ignore("integer_division")
	var q := (n + d / 2) / d
	return -q if (a < 0) != (b < 0) else q


## a * p / 1000, floored (Sub-spec A0: multiply first, divide last).
static func mul_permille(a: int, p: int) -> int:
	return floor_div(a * p, PERMILLE)


static func clamp(v: int, lo: int, hi: int) -> int:
	assert(lo <= hi, "FixedMath.clamp: lo > hi")
	return lo if v < lo else (hi if v > hi else v)


## Largest x with x * x <= n. n must be >= 0.
static func isqrt(n: int) -> int:
	assert(n >= 0, "FixedMath.isqrt: negative input")
	if n < 2:
		return n
	var x := n
	@warning_ignore("integer_division")
	var y := (x + 1) / 2
	while y < x:
		x = y
		@warning_ignore("integer_division")
		y = (x + n / x) / 2
	return x


## a + (b - a) * p / 1000, floored. p = 0 gives a, p = 1000 gives b.
static func lerp_permille(a: int, b: int, p: int) -> int:
	return a + mul_permille(b - a, p)


## Squared distance; compare against a squared radius to avoid square roots.
static func dist2(x1: int, y1: int, x2: int, y2: int) -> int:
	var dx := x2 - x1
	var dy := y2 - y1
	return dx * dx + dy * dy
