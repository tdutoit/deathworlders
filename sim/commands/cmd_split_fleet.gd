class_name CmdSplitFleet
extends Command
## core:cmd/split_fleet {"fleet": ID, "ships": [some of its ships], "name": text (optional)}: those ships form
## a new fleet where they are.

const TYPE := &"core:cmd/split_fleet"


func validate(state: MatchState) -> bool:
	var f := FleetRules.owned(state, player_id, p_int("fleet"))
	if f == null:
		return reject("fleet %d is not yours" % p_int("fleet"))
	var ships: Variant = payload.get("ships", [])
	var reason := FleetRules.check_ships(state, player_id, ships)
	if reason == "" and ((ships as Array).size() >= f.size() or not (ships as Array).all(func(x: Variant) -> bool: return int(x) in f.ships())):
		reason = "split takes some, not all, of the fleet's ships"
	if reason == "":
		reason = FleetRules.check_name(str(payload.get("name", "")))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	Fleets.create(state, player_id, StateIO.ints(payload["ships"]), str(payload.get("name", "")).strip_edges())
