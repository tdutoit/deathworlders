class_name CmdCreateFleet
extends Command
## core:cmd/create_fleet {"ships": [own warship IDs], "name": text (optional)}. The ships must share a system
## and not be moving; they leave their old fleets (main spec 7.1).

const TYPE := &"core:cmd/create_fleet"


func validate(state: MatchState) -> bool:
	var ships: Variant = payload.get("ships", [])
	var reason := FleetRules.check_ships(state, player_id, ships)
	if reason == "":
		reason = FleetRules.check_name(str(payload.get("name", "")))
	if reason == "" and not Fleets.fits(state, StateIO.ints(ships)):
		reason = "too many ships for one fleet"
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	Fleets.create(state, player_id, StateIO.ints(payload["ships"]), str(payload.get("name", "")).strip_edges())
