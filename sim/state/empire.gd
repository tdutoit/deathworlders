class_name Empire
extends RefCounted
## A playing empire (one per player slot).

var id: int
var species: String  # species Def ID
var player_slot: int
var capital_planet: int = StateIO.NONE
var color: String  # "#rrggbb", cosmetic


func to_dict() -> Dictionary:
	return {"id": id, "species": species, "player_slot": player_slot, "capital_planet": capital_planet, "color": color}


static func from_dict(d: Dictionary) -> Empire:
	var e := Empire.new()
	e.id = int(d["id"])
	e.species = String(d["species"])
	e.player_slot = int(d["player_slot"])
	e.capital_planet = int(d["capital_planet"])
	e.color = String(d["color"])
	return e
