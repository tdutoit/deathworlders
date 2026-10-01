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
var hp := 0  # defence stations (M3): combat state from their design
var armor := 0
var shield := 0
var ammo := 0
var crew := 0
var marines := 0
var claim_paid := 0  # outposts: influence (milli) paid when placed, refunded if cancelled (D9)


func to_dict() -> Dictionary:
	return {
		"id": id, "owner": owner, "def_id": def_id, "system_id": system_id, "planet_id": planet_id,
		"operational": operational, "build": build.to_dict() if build else null, "stockpile": stockpile.to_dict(),
		"ship_queue": ship_queue.map(func(q: Construction) -> Dictionary: return q.to_dict()), "claim_paid": claim_paid,
		"hp": hp, "armor": armor, "shield": shield, "ammo": ammo, "crew": crew, "marines": marines,
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
	s.claim_paid = int(d.get("claim_paid", 0))
	s.hp = int(d.get("hp", 0))
	s.armor = int(d.get("armor", 0))
	s.shield = int(d.get("shield", 0))
	s.ammo = int(d.get("ammo", 0))
	s.crew = int(d.get("crew", 0))
	s.marines = int(d.get("marines", 0))
	return s
