class_name CmdSetEscort
extends Command
## core:cmd/set_escort {"fleet": ID, "hub": own hub with berths (0 = end the escort)} (main spec 6.6).
## While the fleet is within the hub's freight range, raids on that hub's freighters succeed at
## combat_rules.escort_raid of the usual chance, and the escort is sent after the raiders.

const TYPE := &"core:cmd/set_escort"


func validate(state: MatchState) -> bool:
	if FleetRules.owned(state, player_id, p_int("fleet")) == null:
		return reject("fleet %d is not yours" % p_int("fleet"))
	var hub := p_int("hub")
	if hub != 0 and (Holders.owner(state, hub) != player_id or Shipyards.berths(state, hub) <= 0):
		return reject("%d is not one of your freight hubs" % hub)
	return true


func apply(state: MatchState) -> void:
	var f: Fleet = state.fleets.get_or(p_int("fleet"))
	f.mission = "escort" if p_int("hub") != 0 else ""
	f.escort_hub = p_int("hub") if p_int("hub") != 0 else StateIO.NONE
	f.patrol.clear()
