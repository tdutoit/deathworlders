class_name Unit
extends RefCounted
## A mobile unit; M1 only has scouts. While moving, path holds the systems still to visit and
## progress counts lane units travelled on the current lane (system_id -> path[0]).

var id: int
var owner: int
var kind: String  # "scout"
var system_id: int
var path: Array[int] = []
var progress: int
var speed: int  # lane units per hour tick


func is_moving() -> bool:
	return not path.is_empty()


func to_dict() -> Dictionary:
	return {
		"id": id, "owner": owner, "kind": kind, "system_id": system_id, "path": path.duplicate(),
		"progress": progress, "speed": speed,
	}


static func from_dict(d: Dictionary) -> Unit:
	var u := Unit.new()
	u.id = int(d["id"])
	u.owner = int(d["owner"])
	u.kind = String(d["kind"])
	u.system_id = int(d["system_id"])
	u.path = StateIO.ints(d["path"])
	u.progress = int(d["progress"])
	u.speed = int(d["speed"])
	return u
