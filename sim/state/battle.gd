class_name Battle
extends RefCounted
## An ongoing space battle in one system (Sub-spec A3–A12): one round per hour tick. Two sides; since M4 each
## side is a coalition of owners (owner decision 2026-10-02): `owners` holds each side's first (lead) owner,
## `sides` every owner on it. Combatants are unit or station IDs grouped in formations (a fleet's task force,
## or one group per owner for ships outside fleets and for stations); morale and retreat are per formation.
## `log` collects what the battle report needs (JSON-safe: String keys, ints and strings only).

var id: int
var system_id: int
var start_tick: int
var round := 0
var band := 0  # range band: 0 Long, 1 Medium, 2 Close (A5)
var owners: Array[int] = []  # [side 0 lead owner, side 1 lead owner]
var sides: Array = [[], []]  # [[side 0 owners], [side 1 owners]]
var formations: Array = []  # [{key, side, members: [ids], morale, hull_start, cost_start, retreat_at,
                            #   range_pref, target, disengage (-1 = no), left (bool)}]
var rng: Array[int] = []  # combat RNG state, seeded match_seed ^ id (A0)
var log := {}


## The side an owner fights on, or -1.
func side_of_owner(owner: int) -> int:
	for s in 2:
		if owner in (sides[s] as Array):
			return s
	return -1


func side_of(combatant: int) -> int:
	for f: Dictionary in formations:
		if not f["left"] and combatant in f["members"]:
			return f["side"]
	return -1


## Combatants still fighting or disengaging (not left), every side or one side.
func active(side := -1) -> Array[int]:
	var out: Array[int] = []
	for f: Dictionary in formations:
		if not f["left"] and (side < 0 or f["side"] == side):
			for m: int in f["members"]:
				out.append(m)
	out.sort()
	return out


func to_dict() -> Dictionary:
	return {"id": id, "system_id": system_id, "start_tick": start_tick, "round": round, "band": band,
		"owners": owners.duplicate(), "sides": sides.duplicate(true), "formations": formations.duplicate(true), "rng": rng.duplicate(),
		"log": log.duplicate(true)}


static func from_dict(d: Dictionary) -> Battle:
	var b := Battle.new()
	b.id = int(d["id"])
	b.system_id = int(d["system_id"])
	b.start_tick = int(d["start_tick"])
	b.round = int(d["round"])
	b.band = int(d["band"])
	b.owners = StateIO.ints(d["owners"])
	var sides: Array = d.get("sides", [[b.owners[0]], [b.owners[1]]])
	b.sides = [StateIO.ints(sides[0]), StateIO.ints(sides[1])]
	for f: Dictionary in d["formations"]:
		var g := f.duplicate(true)
		g["owner"] = g.get("owner", b.owners[int(g["side"])])
		for k in ["side", "owner", "morale", "hull_start", "cost_start", "retreat_at", "disengage"]:
			g[k] = int(g[k])
		g["members"] = StateIO.ints(f["members"])
		g["left"] = f["left"] == true
		b.formations.append(g)
	b.rng = StateIO.ints(d["rng"])
	b.log = StateIO.ints_deep(d.get("log", {}))
	return b
