class_name CmdPrecedenceVeto
extends Command
## core:cmd/precedence_veto {"proposal": ID} (Vess'kar Precedence, M4 WP9): veto this proposal at the session if
## it passes (one veto a session).

const TYPE := &"core:cmd/precedence_veto"


func validate(state: MatchState) -> bool:
	if not SignatureMechanics.of(state, state.empire(player_id)) is PrecedenceMechanic:
		return reject("only the Vess'kar hold Precedence")
	if not Councils.is_member(state, player_id):
		return reject("not a Council member")
	if not state.council.proposals.any(func(p: Dictionary) -> bool: return int(p["id"]) == p_int("proposal")):
		return reject("no such proposal")
	return true


func apply(state: MatchState) -> void:
	state.empire(player_id).mechanic["veto_request"] = p_int("proposal")
