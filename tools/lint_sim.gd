extends SceneTree
## Sim lint (M1 plan section F): fails on code in sim/ that would break determinism.
## Run: godot --headless -s tools/lint_sim.gd   (exit code 1 on violations)
## Also runs inside the test suite (tests/unit/test_sim_lint.gd).
##
## Strings and comments are ignored. To allow a justified exception, end the line with
## `# lint-allow: <rule> <reason>`.

const SIM_DIR := "res://sim"

const RULES := {
	"float": ["\\b\\d+\\.\\d+", "\\d+e[+-]?\\d+\\b", "\\bfloat\\b", "\\bINF\\b", "\\bNAN\\b"],
	"vector": ["\\bVector[234]\\b"],
	"transform": ["\\bTransform(2D|3D)?\\b", "\\bBasis\\b", "\\bQuaternion\\b"],
	"random": ["\\brand[if]\\w*\\b", "\\brandomize\\b", "\\bRandomNumberGenerator\\b"],
	"time": ["\\bTime\\s*\\.", "\\bOS\\s*\\."],
	"file": ["\\bFileAccess\\b", "\\bDirAccess\\b", "\\bResourceLoader\\b", "\\bResourceSaver\\b",
			"(?<![\\w.])load\\s*\\("],
	"node": ["\\bget_node\\w*\\s*\\(", "\\$\\s*[\\w\"%]", "\\bNode(2D|3D)?\\b", "\\bget_tree\\s*\\("],
	"hash": ["\\bhash\\s*\\("],
}


func _init() -> void:
	var problems := lint_dir(SIM_DIR)
	for p in problems:
		printerr(p)
	print("lint_sim: %d problem(s) in %s" % [problems.size(), SIM_DIR])
	quit(1 if problems.size() > 0 else 0)


## Returns "path:line: [rule] code" for every violation under dir (recursive).
static func lint_dir(dir: String) -> Array[String]:
	var compiled := {}
	for rule: String in RULES:
		var list: Array[RegEx] = []
		for pattern: String in RULES[rule]:
			list.append(RegEx.create_from_string(pattern))
		compiled[rule] = list
	var out: Array[String] = []
	for path in _gd_files(dir):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			out.append_array(lint_line(lines[i], compiled, "%s:%d" % [path, i + 1]))
	return out


static func lint_line(line: String, compiled: Dictionary, where: String) -> Array[String]:
	var allowed := _allowed_rules(line)
	var code := strip_strings_and_comments(line)
	var out: Array[String] = []
	for rule: String in compiled:
		if rule in allowed:
			continue
		for re: RegEx in compiled[rule]:
			if re.search(code) != null:
				out.append("%s: [%s] %s" % [where, rule, line.strip_edges()])
				break
	return out


## Replaces string literal contents and drops the trailing comment.
static func strip_strings_and_comments(line: String) -> String:
	var out := ""
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote != "":
			if c == "\\":
				i += 2
				continue
			if c == quote:
				quote = ""
				out += c
		elif c == "#":
			break
		elif c == "\"" or c == "'":
			quote = c
			out += c
		else:
			out += c
		i += 1
	return out


static func _allowed_rules(line: String) -> PackedStringArray:
	var at := line.find("# lint-allow:")
	if at < 0:
		return PackedStringArray()
	var rest := line.substr(at + "# lint-allow:".length()).strip_edges()
	return PackedStringArray([rest.get_slice(" ", 0)])


static func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var subdirs := d.get_directories()
	subdirs.sort()
	for sub in subdirs:
		out.append_array(_gd_files(dir.path_join(sub)))
	var files := d.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
