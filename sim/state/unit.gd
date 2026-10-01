class_name Unit
extends RefCounted
## A mobile unit: scouts, freighters and colony ships in M2. While moving, path holds the systems still to visit and
## progress counts milli-lane-units travelled on the current lane (system_id -> path[0]).

var id: int
var owner: int
var kind: String  # "scout", "freighter", "colony" (the hull's role)
var hull_id: String  # hull Def ID ("" for M1 debug scouts)
var home: int = StateIO.NONE  # freighters: the hub (station or colony ID) whose berth it uses
var system_id: int
var path: Array[int] = []
var progress: int  # milli-lane-units (1 lane unit = 1000)
var speed: int  # milli-lane-units per hour tick


func is_moving() -> bool:
	return not path.is_empty()


func to_dict() -> Dictionary:
	return {
		"id": id, "owner": owner, "kind": kind, "system_id": system_id, "path": path.duplicate(),
		"progress": progress, "speed": speed, "hull_id": hull_id, "home": home,
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
	u.hull_id = String(d.get("hull_id", ""))
	u.home = int(d.get("home", StateIO.NONE))
	return u
