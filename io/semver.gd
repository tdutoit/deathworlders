class_name Semver
extends RefCounted
## "major.minor.patch" versions and space-separated constraints like ">=1.0.0 <2.0.0" (Sub-spec C10).

const OPS: Array[String] = [">=", "<=", ">", "<", "="]


## [major, minor, patch], or [] if malformed.
static func parse(version: String) -> Array[int]:
	var parts := version.strip_edges().split(".")
	if parts.size() != 3:
		return []
	var out: Array[int] = []
	for p in parts:
		if not p.is_valid_int() or p.to_int() < 0:
			return []
		out.append(p.to_int())
	return out


static func compare(a: Array[int], b: Array[int]) -> int:
	for i in 3:
		if a[i] != b[i]:
			return -1 if a[i] < b[i] else 1
	return 0


## True if the constraint is well formed (empty means "any version").
static func is_valid_constraint(constraint: String) -> bool:
	for token in constraint.split(" ", false):
		if parse(_strip_op(token)[1]).is_empty():
			return false
	return true


static func satisfies(version: String, constraint: String) -> bool:
	var v := parse(version)
	if v.is_empty():
		return false
	for token in constraint.split(" ", false):
		var op_ver := _strip_op(token)
		var c := parse(op_ver[1])
		if c.is_empty():
			return false
		var cmp := compare(v, c)
		var ok: bool
		match op_ver[0]:
			">=":
				ok = cmp >= 0
			"<=":
				ok = cmp <= 0
			">":
				ok = cmp > 0
			"<":
				ok = cmp < 0
			_:
				ok = cmp == 0
		if not ok:
			return false
	return true


static func _strip_op(token: String) -> Array[String]:
	for op in OPS:
		if token.begins_with(op):
			return [op, token.substr(op.length())]
	return ["=", token]
