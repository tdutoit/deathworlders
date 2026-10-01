class_name Pace
extends RefCounted
## Pace multiplier (Sub-spec B0): Fast 600, Standard 1000, Epic 1600 permille scales costs and build times.


## A cost or duration under the match pace, floored but never below 1 when the base is positive.
static func scale(amount: int, pace_permille: int) -> int:
	if amount <= 0:
		return amount
	return maxi(1, FixedMath.mul_permille(amount, pace_permille))


## Every value of a resource map scaled.
static func scale_map(amounts: Dictionary, pace_permille: int) -> Dictionary:
	var out := {}
	for k: Variant in amounts:
		out[k] = scale(amounts[k], pace_permille)
	return out
