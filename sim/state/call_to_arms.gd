class_name CallToArms
extends RefCounted
## A partner's call to join a war (E4 defence pact / alliance / protectorate; E3 trust). `from` was attacked by
## `enemy` and calls `to`; answering joins the war (+trust), ignoring it past `deadline_tick` costs trust.

var id: int
var from: int
var to: int
var enemy: int
var tick := 0
var deadline_tick := 0


func to_dict() -> Dictionary:
	return {"id": id, "from": from, "to": to, "enemy": enemy, "tick": tick, "deadline_tick": deadline_tick}


static func from_dict(d: Dictionary) -> CallToArms:
	var c := CallToArms.new()
	c.id = int(d["id"])
	c.from = int(d["from"])
	c.to = int(d["to"])
	c.enemy = int(d["enemy"])
	c.tick = int(d.get("tick", 0))
	c.deadline_tick = int(d.get("deadline_tick", 0))
	return c
