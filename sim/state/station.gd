class_name Station
extends RefCounted
## An orbital station (main spec 5): occupies one orbital slot of a planet, belt or moon, and has its own
## stockpile. While `build` is set it is a construction site (new station) or an upgrade in progress.

var id: int
var owner: int
var def_id: String  # station Def; for a new site, the Def it will become
var system_id: int
var planet_id: int  # the body it orbits
var operational := false  # false while the first construction runs
var build: Construction  # null when idle
var ship_queue: Array[Construction] = []  # shipyards: the first `docks` entries build in parallel (B10)
var stockpile := Stockpile.new()


func to_dict() -> Dictionary:
	return {
		"id": id, "owner": owner, "def_id": def_id, "system_id": system_id, "planet_id": planet_id,
		"operational": operational, "build": build.to_dict() if build else null, "stockpile": stockpile.to_dict(),
		"ship_queue": ship_queue.map(func(q: Construction) -> Dictionary: return q.to_dict()),
	}


static func from_dict(d: Dictionary) -> Station:
	var s := Station.new()
	s.id = int(d["id"])
	s.owner = int(d["owner"])
	s.def_id = String(d["def_id"])
	s.system_id = int(d["system_id"])
	s.planet_id = int(d["planet_id"])
	s.operational = d["operational"] == true
	s.build = Construction.from_dict(d["build"]) if d["build"] is Dictionary else null
	s.stockpile = Stockpile.from_dict(d["stockpile"])
	for q: Dictionary in d.get("ship_queue", []):
		s.ship_queue.append(Construction.from_dict(q))
	return s
