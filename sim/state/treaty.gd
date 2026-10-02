class_name Treaty
extends RefCounted
## An active treaty between two empires (Sub-spec E4; M4 WP4). `a` proposed it (and paid), `b` accepted. For a
## protectorate, `a` is the protected and `b` the guardian. `ends_tick` > 0: notice was given (or the treaty
## is otherwise ending); it lapses cleanly at that tick.

var id: int
var def_id: String
var a: int
var b: int
var start_tick := 0
var ends_tick := 0
var attacked_tick := -1  # protectorate: when the protected was last attacked (guardian must respond), -1 = none


func other(eid: int) -> int:
	return b if eid == a else a


func to_dict() -> Dictionary:
	return {"id": id, "def_id": def_id, "a": a, "b": b, "start_tick": start_tick, "ends_tick": ends_tick,
		"attacked_tick": attacked_tick}


static func from_dict(d: Dictionary) -> Treaty:
	var t := Treaty.new()
	t.id = int(d["id"])
	t.def_id = String(d["def_id"])
	t.a = int(d["a"])
	t.b = int(d["b"])
	t.start_tick = int(d.get("start_tick", 0))
	t.ends_tick = int(d.get("ends_tick", 0))
	t.attacked_tick = int(d.get("attacked_tick", -1))
	return t
