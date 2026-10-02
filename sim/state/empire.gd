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
var mechanic := {}  # signature mechanic state (M4 WP2): string keys, int or string values
var reputation := 0  # E14: -500..500, every empire (Legend for humans is its mechanic, WP9)
var war_exhaustion := 0  # E7: milli-points, 0..100 000
var prewar_fleet := 0  # battle value when its current wars began (exhaustion from losses)
var exhausted_since := -1  # tick exhaustion reached 100 (forced peace after forced_peace_months)
var disarm_until := 0  # E7 disarmament: warship value capped at disarm_cap until this tick
var disarm_cap := 0
var footing := "core:war_footing/peace"  # D7 war footing Def
var footing_until := 0  # transition at half effect until this tick
var demob_until := 0  # demobilisation stability dip until this tick


func to_dict() -> Dictionary:
	return {"id": id, "species": species, "player_slot": player_slot, "capital_planet": capital_planet, "color": color,
		"treasury": treasury.duplicate(), "deficit_months": deficit_months, "credit_net": credit_net,
		"losses": losses.duplicate(true), "tech_fragments": tech_fragments, "mechanic": mechanic.duplicate(true), "reputation": reputation, "war_exhaustion": war_exhaustion,
		"prewar_fleet": prewar_fleet, "exhausted_since": exhausted_since, "disarm_until": disarm_until, "disarm_cap": disarm_cap,
		"footing": footing, "footing_until": footing_until, "demob_until": demob_until}


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
	e.mechanic = StateIO.ints_deep(d.get("mechanic", {}))
	e.reputation = int(d.get("reputation", 0))
	e.war_exhaustion = int(d.get("war_exhaustion", 0))
	e.prewar_fleet = int(d.get("prewar_fleet", 0))
	e.exhausted_since = int(d.get("exhausted_since", -1))
	e.disarm_until = int(d.get("disarm_until", 0))
	e.disarm_cap = int(d.get("disarm_cap", 0))
	e.footing = String(d.get("footing", "core:war_footing/peace"))
	e.footing_until = int(d.get("footing_until", 0))
	e.demob_until = int(d.get("demob_until", 0))
	for l: Dictionary in d.get("losses", []):
		e.losses.append({"tick": int(l["tick"]), "unit": int(l["unit"]), "system": int(l["system"]),
			"hull": String(l["hull"]), "cargo": StateIO.int_map(l["cargo"]), "hub": int(l.get("hub", StateIO.NONE)),
			"by": String(l.get("by", "pirates"))})
	return e
