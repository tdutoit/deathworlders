class_name War
extends RefCounted
## A war between two empires (Sub-spec E7; M4 WP6). `attacker` declared it with `casus_belli` ("" = none);
## allies joining fight their own pair wars. `score_milli` is the attacker's war score against the defender in
## milli-points (-100 000..100 000; the defender's score is its negative).

var id: int
var attacker: int
var defender: int
var start_tick := 0
var casus_belli := ""  # "claim", "retaliation", "protectorate", "containment", "call_to_arms" or ""
var score_milli := 0


## The war score of `eid` (one of the two) in whole points.
func score_of(eid: int) -> int:
	var s := score_milli if eid == attacker else -score_milli
	return s / 1000


func add_score(eid: int, milli: int) -> void:
	score_milli = clampi(score_milli + (milli if eid == attacker else -milli), -100000, 100000)


func to_dict() -> Dictionary:
	return {"id": id, "attacker": attacker, "defender": defender, "start_tick": start_tick,
		"casus_belli": casus_belli, "score_milli": score_milli}


static func from_dict(d: Dictionary) -> War:
	var w := War.new()
	w.id = int(d["id"])
	w.attacker = int(d["attacker"])
	w.defender = int(d["defender"])
	w.start_tick = int(d.get("start_tick", 0))
	w.casus_belli = String(d.get("casus_belli", ""))
	w.score_milli = int(d.get("score_milli", 0))
	return w
