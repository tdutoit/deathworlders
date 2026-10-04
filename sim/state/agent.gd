class_name Agent
extends RefCounted
## An espionage agent (main spec 12; M5 WP9).

var id: int
var owner: int  # the empire running it
var target: int  # the empire it works against
var mission := "gather_intel"  # Espionage.MISSIONS
var ready_tick := 0  # in place (missions and rolls) from this tick


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "target": target, "mission": mission, "ready_tick": ready_tick}


static func from_dict(d: Dictionary) -> Agent:
	var a := Agent.new()
	a.id = int(d["id"])
	a.owner = int(d["owner"])
	a.target = int(d["target"])
	a.mission = String(d["mission"])
	a.ready_tick = int(d["ready_tick"])
	return a
