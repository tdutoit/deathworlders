class_name CmdHireMercenaries
extends Command
## core:cmd/hire_mercenaries {} (Ohlan Contracts, M4 WP9): a mercenary fleet for a year.

const TYPE := &"core:cmd/hire_mercenaries"


func validate(state: MatchState) -> bool:
	var reason := ContractsMechanic.check_hire(state, player_id)
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	ContractsMechanic.hire(state, player_id)
