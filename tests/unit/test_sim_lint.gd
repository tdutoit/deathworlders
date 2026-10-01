extends GutTest
# M1 plan section F: sim/ must stay free of floats, Godot randomness, file/OS/time access and Nodes.

const Lint := preload("res://tools/lint_sim.gd")

var _compiled: Dictionary


func before_all() -> void:
	for rule: String in Lint.RULES:
		var list: Array[RegEx] = []
		for pattern: String in Lint.RULES[rule]:
			list.append(RegEx.create_from_string(pattern))
		_compiled[rule] = list


func _rules_hit(line: String) -> Array:
	var rules := []
	for problem in Lint.lint_line(line, _compiled, "t"):
		rules.append(problem.get_slice("[", 1).get_slice("]", 0))
	return rules


func test_sim_folder_is_clean() -> void:
	var problems := Lint.lint_dir(Lint.SIM_DIR)
	assert_eq(problems, [] as Array[String], "\n".join(problems))


func test_catches_banned_code() -> void:
	assert_eq(_rules_hit("var x := 1.5"), ["float"])
	assert_eq(_rules_hit("var x: float = 1"), ["float"])
	assert_eq(_rules_hit("var p := Vector2(1, 2)"), ["vector"])
	assert_eq(_rules_hit("var r := randi() % 6"), ["random"])
	assert_eq(_rules_hit("var t := Time.get_ticks_msec()"), ["time"])
	assert_eq(_rules_hit("var f := FileAccess.open(p, FileAccess.READ)"), ["file"])
	assert_eq(_rules_hit("var n := get_node(\"A\")"), ["node"])
	assert_eq(_rules_hit("var n := $Camera"), ["node"])
	assert_eq(_rules_hit("var h := s.hash()"), ["hash"])
	assert_eq(_rules_hit("var s := load(\"res://x.tres\")"), ["file"])


func test_ignores_strings_comments_and_safe_code() -> void:
	assert_eq(_rules_hit("var s := \"1.5 Vector2 randi() $x\"  # Time.now 2.5"), [])
	assert_eq(_rules_hit("var p := Vector2i(1, 2)"), [])
	assert_eq(_rules_hit("var h := DetHash.hash_value(x)"), [])
	assert_eq(_rules_hit("var r := rng.range(0, 1000)"), [])
	assert_eq(_rules_hit("var v := version.to_int()  # 1.2.0"), [])


func test_lint_allow_comment() -> void:
	assert_eq(_rules_hit("var x := 0.5  # lint-allow: float reason here"), [])
	assert_eq(_rules_hit("var x := randf() * 0.5  # lint-allow: float reason"), ["random"])
