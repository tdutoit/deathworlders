class_name Proposal
extends RefCounted
## A treaty proposal waiting for a player's answer (AI targets answer at once by E5; M4 WP4).

var id: int
var def_id: String
var from: int
var to: int
var tick := 0
var expires_tick := 0
var items: Array = []  # deal items (WP5); def_id may be "" for a deal without a treaty


func to_dict() -> Dictionary:
	return {"id": id, "def_id": def_id, "from": from, "to": to, "tick": tick, "expires_tick": expires_tick, "items": items.duplicate(true)}


static func from_dict(d: Dictionary) -> Proposal:
	var p := Proposal.new()
	p.id = int(d["id"])
	p.def_id = String(d["def_id"])
	p.from = int(d["from"])
	p.to = int(d["to"])
	p.tick = int(d.get("tick", 0))
	p.expires_tick = int(d.get("expires_tick", 0))
	p.items = StateIO.ints_deep(d.get("items", []))
	return p
