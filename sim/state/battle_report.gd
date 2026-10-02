class_name BattleReport
extends RefCounted
## A finished battle's record (main spec 7.7, F11): JSON-safe data the Battle Report screen reads.
## Keys: system, start_tick, end_tick, rounds, owners [a, b], results [a, b] (A12 classes), start_cost,
## lost_cost, salvage, strength (per round [a, b] hull), bands (per round range band), lost / captured / retreated lists, family stats,
## damage and kills per combatant, names (combatant -> [owner, hull class, design name]), events.

var id: int
var data := {}


## The side an empire fought on (coalitions since M4: data["sides"]), or -1.
func side_of(eid: int) -> int:
	var sides: Array = data.get("sides", [[data["owners"][0]], [data["owners"][1]]])
	for s in 2:
		if eid in (sides[s] as Array):
			return s
	return -1


## Every owner that fought, both sides.
func all_owners() -> Array:
	var sides: Array = data.get("sides", [[data["owners"][0]], [data["owners"][1]]])
	return (sides[0] as Array) + (sides[1] as Array)


func to_dict() -> Dictionary:
	return {"id": id, "data": data.duplicate(true)}


static func from_dict(d: Dictionary) -> BattleReport:
	var r := BattleReport.new()
	r.id = int(d["id"])
	r.data = StateIO.ints_deep(d["data"])
	return r
