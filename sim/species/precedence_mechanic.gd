class_name PrecedenceMechanic
extends SignatureMechanic
## Precedence (Vess'kar; main spec 10.1, Sub-spec E9; M4 WP9, owner placeholders): +2 Council votes while a
## member, one veto a session (a player marks the proposal to veto; the AI vetoes passed resolutions it scores at
## or below veto_stance), and stagnation: one point a year without adapting (a new treaty, a resolution of its
## own passed, a war won); each point beyond stagnation_free costs stagnation_step permille of all job output.
## State: {"stagnation", "last_adapt" (tick), "veto_session" (session index of the last veto), "veto_request"}.


func init_state(state: MatchState, e: Empire) -> void:
	e.mechanic = {"stagnation": 0, "last_adapt": state.tick, "veto_session": -1, "veto_request": -1}


func month_tick(state: MatchState, e: Empire) -> void:
	e.mechanic["stagnation"] = FixedMath.floor_div(state.tick - int(e.mechanic.get("last_adapt", 0)), Calendar.HOURS_PER_YEAR)


func treaty_event(state: MatchState, e: Empire, event: Dictionary) -> void:
	if String(event.get("type", "")) in ["treaty_signed", "resolution_passed", "war_won"]:
		e.mechanic["last_adapt"] = state.tick
		e.mechanic["stagnation"] = 0


func output_permille(state: MatchState, e: Empire) -> int:
	var r := SignatureMechanics.rules(state)
	var over := int(e.mechanic.get("stagnation", 0)) - r.stagnation_free
	return maxi(r.stagnation_max, over * r.stagnation_step) if over > 0 else 0


func council_votes(state: MatchState, e: Empire) -> int:
	return SignatureMechanics.rules(state).precedence_votes if Councils.is_member(state, e.id) else 0


func council_veto(state: MatchState, e: Empire, proposal: Dictionary) -> bool:
	if not Councils.is_member(state, e.id) or int(e.mechanic.get("veto_session", -1)) == state.council.sessions:
		return false
	var veto: bool
	if Autopilot.is_ai(state, e.id):
		veto = Councils.ai_score(state, e.id, proposal) <= SignatureMechanics.rules(state).veto_stance
	else:
		veto = int(e.mechanic.get("veto_request", -1)) == int(proposal["id"])
	if veto:
		e.mechanic["veto_session"] = state.council.sessions
		e.mechanic["veto_request"] = -1
	return veto


func meter(state: MatchState, e: Empire) -> Dictionary:
	return {"PRECEDENCE_STAGNATION": int(e.mechanic.get("stagnation", 0)), "PRECEDENCE_VOTES": Councils.votes(state, e.id)}
