class_name BattleReport
extends RefCounted
## A finished battle's record (main spec 7.7, F11): JSON-safe data the Battle Report screen reads.
## Keys: system, start_tick, end_tick, rounds, owners [a, b], results [a, b] (A12 classes), start_cost,
## lost_cost, salvage, strength (per round [a, b] hull), bands (per round range band), lost / captured / retreated lists, family stats,
## damage and kills per combatant, names (combatant -> [owner, hull class, design name]), events.

var id: int
var data := {}


func to_dict() -> Dictionary:
	return {"id": id, "data": data.duplicate(true)}


static func from_dict(d: Dictionary) -> BattleReport:
	var r := BattleReport.new()
	r.id = int(d["id"])
	r.data = StateIO.ints_deep(d["data"])
	return r
