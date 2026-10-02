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
var tech_fragments := 0  # battle salvage (A12), spent in M5
var credit_net := 0  # last month: credits produced (jobs, buildings, taxes) minus upkeep due, milli
var losses: Array[Dictionary] = []  # convoy losses, newest last (B9; kept to LOSS_LOG entries)


func to_dict() -> Dictionary:
	return {"id": id, "species": species, "player_slot": player_slot, "capital_planet": capital_planet, "color": color,
		"treasury": treasury.duplicate(), "deficit_months": deficit_months, "credit_net": credit_net,
		"losses": losses.duplicate(true), "tech_fragments": tech_fragments}


static func from_dict(d: Dictionary) -> Empire:
	var e := Empire.new()
	e.id = int(d["id"])
	e.species = String(d["species"])
	e.player_slot = int(d["player_slot"])
	e.capital_planet = int(d["capital_planet"])
	e.color = String(d["color"])
	e.treasury = StateIO.int_map(d.get("treasury", {}))
	e.deficit_months = int(d.get("deficit_months", 0))
	e.credit_net = int(d.get("credit_net", 0))
	e.tech_fragments = int(d.get("tech_fragments", 0))
	for l: Dictionary in d.get("losses", []):
		e.losses.append({"tick": int(l["tick"]), "unit": int(l["unit"]), "system": int(l["system"]),
			"hull": String(l["hull"]), "cargo": StateIO.int_map(l["cargo"]), "hub": int(l.get("hub", StateIO.NONE)),
			"by": String(l.get("by", "pirates"))})
	return e
