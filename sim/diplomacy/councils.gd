class_name Councils
extends RefCounted
## Galactic Council rules (Sub-spec E9; M4 WP8, owner decisions 2026-10-02): founding, proposals, votes,
## sessions every council_session_months, resolutions in force until repealed, and defiance. The council lives
## in MatchState.council. Precedence (Vess'kar: +2 votes, one veto a session) plugs in through the signature
## mechanics (WP9).


static func rules(state: MatchState) -> DiplomacyRulesDef:
	return Relations.rules(state)


static func council(state: MatchState) -> Council:
	return state.council


static func is_member(state: MatchState, eid: int) -> bool:
	return state.council != null and eid in state.council.members


## Match start: every Vess'kar empire founds the Council; with none, the empire whose species has the highest
## Ambition (ties: lowest ID).
static func found(state: MatchState) -> void:
	var c := Council.new()
	for eid: int in state.empires.ordered():
		if state.empire(eid).species == "core:species/vesskar":
			c.members.append(eid)
	for p: Dictionary in state.settings.players:  # founding seats from match setup (E9)
		if p.get("council_seat", false) == true:
			for eid: int in state.empires.ordered():
				if state.empire(eid).player_slot == int(p["slot"]) and not eid in c.members:
					c.members.append(eid)
	if c.members.is_empty():
		var best := -1
		var best_amb := -1
		for eid: int in state.empires.ordered():
			var amb := Treaties.personality(state, eid, "ambition")
			if amb > best_amb:
				best = eid
				best_amb = amb
		if best >= 0:
			c.members.append(best)
	c.next_session = state.tick + rules(state).council_session_months * Calendar.HOURS_PER_MONTH
	state.council = c


## E9 votes: 1 + influence income / votes_influence_step + protectorates held + mechanic bonuses (Precedence).
static func votes(state: MatchState, eid: int) -> int:
	var income := 0
	for pid: int in state.colonies.ordered():
		var col: Colony = state.colonies.get_or(pid)
		if col.owner == eid:
			income += int(col.last_produced.get("core:resource/influence", 0))
	var v := 1 + FixedMath.floor_div(income, rules(state).votes_influence_step * Stockpile.MILLI)
	for tid: int in state.treaties.ordered():
		var t: Treaty = state.treaties.get_or(tid)
		if t.b == eid and Treaties.def_of(state, t.def_id).has("protectorate"):
			v += 1
	return v + SignatureMechanics.council_votes(state, eid)


static func def_of(state: MatchState, def_id: String) -> ResolutionDef:
	return state.defs.get_def(StringName(def_id)) as ResolutionDef


## Active resolutions of an effect (optionally against one target).
static func in_force(state: MatchState, effect: String, target := -2) -> Array:
	var out := []
	if state.council == null:
		return out
	for a: Dictionary in state.council.active:
		var d := def_of(state, a["def"])
		if d != null and String(d.effect) == effect and (target == -2 or int(a["target"]) == target):
			out.append(a)
	return out


## "" if `eid` may put this proposal to the next session, else why.
static func check_propose(state: MatchState, eid: int, def_id: String, target: int, repeal: int) -> String:
	var c := state.council
	if c == null or not eid in c.members:
		return "only Council members propose resolutions"
	if c.proposals.any(func(p: Dictionary) -> bool: return int(p["proposer"]) == eid):
		return "one proposal a session"
	if int(state.empire(eid).treasury.get("core:resource/influence", 0)) < rules(state).council_proposal_influence * Stockpile.MILLI:
		return "needs %d influence" % rules(state).council_proposal_influence
	if repeal >= 0:
		if not c.active.any(func(a: Dictionary) -> bool: return int(a["id"]) == repeal):
			return "no such resolution in force"
		return ""
	var d := def_of(state, def_id)
	if d == null:
		return "unknown resolution %s" % def_id
	if d.needs_target and state.empire(target) == null:
		return "this resolution needs a target empire"
	if String(d.effect) == "recognition" and target in c.members:
		return "already a member"
	if not d.needs_target and not in_force(state, String(d.effect)).is_empty():
		return "already in force"
	return ""


static func propose(state: MatchState, eid: int, def_id: String, target: int, repeal: int) -> void:
	var e := state.empire(eid)
	e.treasury["core:resource/influence"] = int(e.treasury["core:resource/influence"]) - rules(state).council_proposal_influence * Stockpile.MILLI
	state.council.proposals.append({"id": state.alloc_id(), "proposer": eid, "def": def_id, "target": target,
		"repeal": repeal, "votes": {str(eid): 1}})  # the proposer votes for it unless it changes its vote


## A member's vote: +1 for, -1 against, 0 to abstain (players set theirs; AI members decide at the session).
static func cast(state: MatchState, eid: int, proposal_id: int, vote: int) -> void:
	for p: Dictionary in state.council.proposals:
		if int(p["id"]) == proposal_id:
			p["votes"][str(eid)] = vote


## AI vote (E9: by personality and opinion of the proposer; owner placeholder weights): for when its score is
## positive; the proposer always votes for its own proposal.
static func ai_vote(state: MatchState, voter: int, p: Dictionary) -> int:
	if voter == int(p["proposer"]):
		return 1
	return 1 if ai_score(state, voter, p) > 0 else -1


## How much an AI member likes a proposal: opinion of the proposer / 2 plus its stance on the resolution.
static func ai_score(state: MatchState, voter: int, p: Dictionary) -> int:
	var proposer := int(p["proposer"])
	var score := 0 if voter == proposer else FixedMath.floor_div(Relations.opinion(state, voter, proposer), 2)
	var repeal := int(p["repeal"])
	var def_id: String = p["def"]
	var target := int(p["target"])
	if repeal >= 0:
		for a: Dictionary in state.council.active:
			if int(a["id"]) == repeal:
				def_id = a["def"]
				target = int(a["target"])
	var stance := 0
	match String(def_of(state, def_id).effect):
		"trade_standards":
			stance = Treaties.personality(state, voter, "greed") - 50
		"sanctions":
			if voter == target:
				stance = -100
			elif Relations.has_contact(state, voter, target):
				stance = -Relations.opinion(state, voter, target)
			if Treaties.allied(state, voter, target):
				stance -= 50
		"pirate_suppression":
			stance = Treaties.personality(state, voter, "caution") - 40
		"recognition":
			stance = (Relations.opinion(state, voter, target) if Relations.has_contact(state, voter, target) else -20) \
				+ Treaties.personality(state, voter, "xenophilia") - 50
	score += -stance if repeal >= 0 else stance
	return score


## Monthly: hold the session when due.
static func month_tick(state: MatchState) -> void:
	if state.council == null or state.defs == null:
		return
	for eid: int in state.empires.ordered():
		if not eid in state.council.members and SignatureMechanics.auto_recognition(state, eid):
			state.council.members.append(eid)  # Legend: Respect 800 (E14)
	if state.tick < state.council.next_session:
		return
	session(state)


## E9 session: every proposal in order; passes on more weighted yes than no among voting members; a passed
## resolution takes force (or its repeal removes one); Precedence may veto (WP9).
static func session(state: MatchState) -> void:
	var c := state.council
	var r := rules(state)
	c.last_session = []
	for p: Dictionary in c.proposals:
		var yes := 0
		var no := 0
		var voted_for: Array[int] = []
		for m: int in c.members:
			var v := int(p["votes"].get(str(m), 0)) if not Autopilot.is_ai(state, m) else ai_vote(state, m, p)
			if v > 0:
				yes += votes(state, m)
				voted_for.append(m)
			elif v < 0:
				no += votes(state, m)
		var passed := yes > no
		var vetoed := passed and SignatureMechanics.council_veto(state, p)
		if passed and not vetoed:
			_enact(state, p, voted_for)
			SignatureMechanics.treaty_event(state, int(p["proposer"]), {"type": "resolution_passed", "def": p["def"]})
		c.last_session.append({"def": p["def"], "target": p["target"], "repeal": p["repeal"], "proposer": p["proposer"],
			"yes": yes, "no": no, "passed": passed and not vetoed, "vetoed": vetoed})
	c.proposals = []
	c.sessions += 1
	c.next_session = state.tick + r.council_session_months * Calendar.HOURS_PER_MONTH


static func _enact(state: MatchState, p: Dictionary, voted_for: Array[int]) -> void:
	var c := state.council
	var repeal := int(p["repeal"])
	if repeal >= 0:
		c.active = c.active.filter(func(a: Dictionary) -> bool: return int(a["id"]) != repeal)
		return
	var d := def_of(state, p["def"])
	if String(d.effect) == "recognition":
		if not int(p["target"]) in c.members:
			c.members.append(int(p["target"]))
		return
	c.active.append({"id": p["id"], "def": p["def"], "target": p["target"], "proposer": p["proposer"], "tick": state.tick,
		"for": voted_for})


# --- effects ---

## Trade Standards: Clerk credits for members (+) and non-members (-), permille.
static func clerk_credits_permille(state: MatchState, eid: int) -> int:
	var out := 0
	for a: Dictionary in in_force(state, "trade_standards"):
		var v := def_of(state, a["def"]).value
		out += v if is_member(state, eid) else -v
	return out


## Pirate Suppression Mandate: security in member space.
static func security_bonus(state: MatchState, system_owner: int) -> int:
	if not is_member(state, system_owner):
		return 0
	var out := 0
	for a: Dictionary in in_force(state, "pirate_suppression"):
		out += def_of(state, a["def"]).value
	return out


## Sanctions on X: standing opinion of each member toward X (Relations.month_tick adds it).
static func sanctions_standing(state: MatchState, member: int, target: int) -> int:
	if not is_member(state, member):
		return 0
	var out := 0
	for a: Dictionary in in_force(state, "sanctions", target):
		out += def_of(state, a["def"]).value
	return out


## Defiance (E9): a member treating or dealing with a sanctioned empire: -15 opinion and -10 trust from each
## member that voted for the sanctions.
static func on_dealing(state: MatchState, a: int, b: int) -> void:
	var r := rules(state)
	for pair: Array in [[a, b], [b, a]]:
		if not is_member(state, pair[0]):
			continue
		for s: Dictionary in in_force(state, "sanctions", pair[1]):
			for voter: int in s["for"]:
				if voter != pair[0] and Relations.has_contact(state, voter, pair[0]):
					Relations.add_event(state, voter, pair[0], "defiance", r.defiance_opinion)
					Relations.change_trust(state, voter, pair[0], r.defiance_trust)
