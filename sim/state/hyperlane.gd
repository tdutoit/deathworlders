class_name Hyperlane
extends RefCounted
## A lane between two systems; corridors between clusters are lanes too (main spec 3.4).

var id: int
var a: int  # system ID (a < b)
var b: int
var length: int  # lane units (B7: 20-40 inside a cluster); movement uses length * 1000


func other_end(system_id: int) -> int:
	return b if system_id == a else a


func to_dict() -> Dictionary:
	return {"id": id, "a": a, "b": b, "length": length}


static func from_dict(d: Dictionary) -> Hyperlane:
	var l := Hyperlane.new()
	l.id = int(d["id"])
	l.a = int(d["a"])
	l.b = int(d["b"])
	l.length = int(d["length"])
	return l
