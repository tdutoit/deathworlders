class_name Relation
extends RefCounted
## One empire's view of another (Sub-spec E1; directed: A's view of B can differ from B's view of A).
## Exists from first contact. Opinion itself is derived (Relations.opinion): species affinity + standing
## modifiers (recomputed monthly while their condition holds) + event modifiers (decaying).

var from: int
var to: int
var contact_tick := 0
var trust := 0  # E3: 0..trust_max, moved only by deeds
var standing := {}  # modifier type -> value while true (border, common_enemy; treaties from WP4)
var events := {}  # event type -> [value, months since its last decay step]
var refusals := {}  # treaty Def ID -> tick this empire last refused it (E5 recent refusal)


func to_dict() -> Dictionary:
	return {"from": from, "to": to, "contact_tick": contact_tick, "trust": trust, "standing": standing.duplicate(),
		"events": events.duplicate(true), "refusals": refusals.duplicate()}


static func from_dict(d: Dictionary) -> Relation:
	var r := Relation.new()
	r.from = int(d["from"])
	r.to = int(d["to"])
	r.contact_tick = int(d["contact_tick"])
	r.trust = int(d["trust"])
	r.standing = StateIO.ints_deep(d.get("standing", {}))
	r.events = StateIO.ints_deep(d.get("events", {}))
	r.refusals = StateIO.ints_deep(d.get("refusals", {}))
	return r
