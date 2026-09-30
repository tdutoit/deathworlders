extends GutTest
# M1 WP2: FixedMath edge cases (negatives, rounding, zero).


func test_floor_div_rounds_down() -> void:
	assert_eq(FixedMath.floor_div(7, 2), 3)
	assert_eq(FixedMath.floor_div(-7, 2), -4)
	assert_eq(FixedMath.floor_div(7, -2), -4)
	assert_eq(FixedMath.floor_div(-7, -2), 3)
	assert_eq(FixedMath.floor_div(-6, 2), -3)
	assert_eq(FixedMath.floor_div(0, 5), 0)


func test_div_round_halves_away_from_zero() -> void:
	assert_eq(FixedMath.div_round(5, 2), 3)
	assert_eq(FixedMath.div_round(-5, 2), -3)
	assert_eq(FixedMath.div_round(5, -2), -3)
	assert_eq(FixedMath.div_round(-5, -2), 3)
	assert_eq(FixedMath.div_round(4, 3), 1)
	assert_eq(FixedMath.div_round(5, 3), 2)
	assert_eq(FixedMath.div_round(-4, 3), -1)
	assert_eq(FixedMath.div_round(-5, 3), -2)
	assert_eq(FixedMath.div_round(1, 3), 0)
	assert_eq(FixedMath.div_round(0, 7), 0)


func test_mul_permille() -> void:
	assert_eq(FixedMath.mul_permille(1000, 750), 750)
	assert_eq(FixedMath.mul_permille(333, 500), 166)  # 166.5 floors
	assert_eq(FixedMath.mul_permille(-333, 500), -167)  # -166.5 floors
	assert_eq(FixedMath.mul_permille(-1, 500), -1)
	assert_eq(FixedMath.mul_permille(12345, 0), 0)
	assert_eq(FixedMath.mul_permille(0, 999), 0)
	assert_eq(FixedMath.mul_permille(200, 1250), 250)
	assert_eq(FixedMath.mul_permille(1 << 50, 2000), 1 << 51, "large values within the 2^62 limit")


func test_clamp() -> void:
	assert_eq(FixedMath.clamp(5, 0, 10), 5)
	assert_eq(FixedMath.clamp(-5, 0, 10), 0)
	assert_eq(FixedMath.clamp(15, 0, 10), 10)
	assert_eq(FixedMath.clamp(-5, -10, -1), -5)
	assert_eq(FixedMath.clamp(3, 3, 3), 3)


func test_isqrt() -> void:
	assert_eq(FixedMath.isqrt(0), 0)
	assert_eq(FixedMath.isqrt(1), 1)
	assert_eq(FixedMath.isqrt(2), 1)
	assert_eq(FixedMath.isqrt(3), 1)
	assert_eq(FixedMath.isqrt(4), 2)
	assert_eq(FixedMath.isqrt(99), 9)
	assert_eq(FixedMath.isqrt(100), 10)
	assert_eq(FixedMath.isqrt((1 << 60) - 1), (1 << 30) - 1)
	assert_eq(FixedMath.isqrt(1 << 60), 1 << 30)
	var big := (1 << 62) - 1
	var r := FixedMath.isqrt(big)
	assert_true(r * r <= big and (r + 1) * (r + 1) > big, "isqrt near 2^62")


func test_lerp_permille() -> void:
	assert_eq(FixedMath.lerp_permille(100, 200, 0), 100)
	assert_eq(FixedMath.lerp_permille(100, 200, 1000), 200)
	assert_eq(FixedMath.lerp_permille(100, 200, 500), 150)
	assert_eq(FixedMath.lerp_permille(200, 100, 333), 166)  # 200 - 33.3 floors to 166
	assert_eq(FixedMath.lerp_permille(-10, 10, 250), -5)


func test_dist2() -> void:
	assert_eq(FixedMath.dist2(0, 0, 3, 4), 25)
	assert_eq(FixedMath.dist2(3, 4, 0, 0), 25)
	assert_eq(FixedMath.dist2(-5, -5, -5, -5), 0)
	var edge := (1 << 30) - 1
	assert_eq(FixedMath.dist2(0, 0, edge, edge), 2 * edge * edge)
