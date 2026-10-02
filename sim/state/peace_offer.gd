class_name PeaceOffer
extends RefCounted
## A peace offer waiting for a player's answer (E7; AI targets answer at once). Terms are what the loser gives:
## {"type": "white" | "cede_system" | "reparations" | "humiliation" | "disarmament", "ref": system ID (cede),
## "amount": credit value (reparations)}; `loser` is the side giving them.

var id: int
var from: int
var to: int
var loser: int
var terms: Array = []
var tick := 0
var expires_tick := 0


func to_dict() -> Dictionary:
	return {"id": id, "from": from, "to": to, "loser": loser, "terms": terms.duplicate(true), "tick": tick,
		"expires_tick": expires_tick}


static func from_dict(d: Dictionary) -> PeaceOffer:
	var p := PeaceOffer.new()
	p.id = int(d["id"])
	p.from = int(d["from"])
	p.to = int(d["to"])
	p.loser = int(d["loser"])
	p.terms = StateIO.ints_deep(d.get("terms", []))
	p.tick = int(d.get("tick", 0))
	p.expires_tick = int(d.get("expires_tick", 0))
	return p
