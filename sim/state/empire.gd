class_name Empire
extends RefCounted
## A playing empire (one per player slot).

var id: int
var species: String  # species Def ID
var player_slot: int
var capital_planet: int = StateIO.NONE
var color: String  # "#rrggbb", cosmetic
var treasury := {}  # global resource ID (credits, research, influence) -> milli-units (B0, B13-B16)
var deficit_months := 0  # consecutive months that upkeep couldn't be paid (B13)


func to_dict() -> Dictionary:
	return {"id": id, "species": species, "player_slot": player_slot, "capital_planet": capital_planet, "color": color,
		"treasury": treasury.duplicate(), "deficit_months": deficit_months}


static func from_dict(d: Dictionary) -> Empire:
	var e := Empire.new()
	e.id = int(d["id"])
	e.species = String(d["species"])
	e.player_slot = int(d["player_slot"])
	e.capital_planet = int(d["capital_planet"])
	e.color = String(d["color"])
	e.treasury = StateIO.int_map(d.get("treasury", {}))
	e.deficit_months = int(d.get("deficit_months", 0))
	return e
