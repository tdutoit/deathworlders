class_name Knowledge
extends RefCounted
## One empire's knowledge model (Sub-spec D12; M5 WP5): what it has explored, what its sensors cover now,
## which foreign units it sees and the ghosts of those it lost track of. Recomputed daily by Fog.

var id: int  # the empire
var explored := {}  # system ID -> [owner as last seen, tick last covered]
var covered := {}  # system ID -> sensor strength covering it now (own and allied sources)
var visible := {}  # foreign unit ID -> true, detected now
var ghosts := {}  # unit ID -> {"system", "owner", "kind", "size", "tick"} last seen; fade after ghost_days
var intel := {}  # other empire ID -> intel points (Intel, WP6)
var fought := {}  # other empire ID -> true once they met in battle (intel floor: level 1)


func to_dict() -> Dictionary:
	var g := []
	for uid: int in IdMap.sort_keys(ghosts.keys()):
		var x: Dictionary = ghosts[uid]
		g.append([uid, x["system"], x["owner"], x["kind"], x["size"], x["tick"]])
	var e := []
	for sid: int in IdMap.sort_keys(explored.keys()):
		e.append([sid, explored[sid][0], explored[sid][1]])
	var c := []
	for sid: int in IdMap.sort_keys(covered.keys()):
		c.append([sid, covered[sid]])
	return {"id": id, "explored": e, "covered": c, "visible": IdMap.sort_keys(visible.keys()), "ghosts": g,
		"intel": intel.duplicate(), "fought": IdMap.sort_keys(fought.keys())}


static func from_dict(d: Dictionary) -> Knowledge:
	var k := Knowledge.new()
	k.id = int(d["id"])
	for row: Array in d.get("explored", []):
		k.explored[int(row[0])] = [int(row[1]), int(row[2])]
	for row: Array in d.get("covered", []):
		k.covered[int(row[0])] = int(row[1])
	for uid: Variant in d.get("visible", []):
		k.visible[int(uid)] = true
	k.intel = StateIO.int_map(d.get("intel", {}))
	for o: Variant in d.get("fought", []):
		k.fought[int(o)] = true
	for row: Array in d.get("ghosts", []):
		k.ghosts[int(row[0])] = {"system": int(row[1]), "owner": int(row[2]), "kind": String(row[3]),
			"size": String(row[4]), "tick": int(row[5])}
	return k
