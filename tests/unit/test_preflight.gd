extends GutTest
# Placeholder proving the test pipeline runs headless (M1 Plan D0.6).

func test_int_is_64_bit():
	assert_eq(9223372036854775807 + 0, 9223372036854775807, "GDScript int must be 64-bit")

func test_mul32_fits():
	# Largest intermediate in the planned mul32 helper stays below 2^48.
	var a := 0xFFFFFFFF
	assert_true(a * 0xFFFF < (1 << 48))
