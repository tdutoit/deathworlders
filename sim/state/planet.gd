class_name Planet
extends RefCounted
## A planet (main spec 4.1). Size is one of PlanetTypeDef.SIZES.

var id: int
var system_id: int
var name: String
var planet_type: String  # planet_type Def ID
var size: String  # "tiny" .. "huge"
var orbit_index: int  # 0 = innermost
var orbit_radius: int
var deposits: Dictionary = {}  # resource Def ID -> amount
var owner: int = StateIO.NONE
var orbital_slots: int


func to_dict() -> Dictionary:
	return {
		"id": id, "system_id": system_id, "name": name, "planet_type": planet_type, "size": size,
		"orbit_index": orbit_index, "orbit_radius": orbit_radius, "deposits": deposits.duplicate(),
		"owner": owner, "orbital_slots": orbital_slots,
	}


static func from_dict(d: Dictionary) -> Planet:
	var p := Planet.new()
	p.id = int(d["id"])
	p.system_id = int(d["system_id"])
	p.name = String(d["name"])
	p.planet_type = String(d["planet_type"])
	p.size = String(d["size"])
	p.orbit_index = int(d["orbit_index"])
	p.orbit_radius = int(d["orbit_radius"])
	p.deposits = StateIO.int_map(d["deposits"])
	p.owner = int(d["owner"])
	p.orbital_slots = int(d["orbital_slots"])
	return p
