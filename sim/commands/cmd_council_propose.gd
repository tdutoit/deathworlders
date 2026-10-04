class_name CmdCouncilPropose
extends Command
## core:cmd/council_propose {"resolution": resolution Def ID, "target": empire ID (or -1), "repeal": active
## resolution ID to repeal (or -1)} (E9): one proposal a session per member, 30 influence. A non-member
## with the goodwill of most members may propose its own Recognition (an application, owner 2026-10-03).

const TYPE := &"core:cmd/council_propose"


func validate(state: MatchState) -> bool:
	var reason := Councils.check_propose(state, player_id, str(payload.get("resolution", "")), p_int("target", -1), p_int("repeal", -1))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	Councils.propose(state, player_id, str(payload.get("resolution", "")), p_int("target", -1), p_int("repeal", -1))
