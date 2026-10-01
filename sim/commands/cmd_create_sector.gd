class_name CmdCreateSector
extends Command
## core:cmd/create_sector {"hub": Logistics Station T2+ or Logistics-focus colony} (Sub-spec D3)

const TYPE := &"core:cmd/create_sector"


func validate(state: MatchState) -> bool:
	var reason := Sectors.check_hub(state, player_id, p_int("hub"))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	Sectors.create(state, player_id, p_int("hub"))
