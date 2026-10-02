class_name StrategicAI
extends RefCounted
## The strategic AI for AI slots (Sub-spec E11-E12, D10; M4 WP10). Monthly, after the economic autopilot:
## assess, score candidate diplomatic and war actions with integer utilities, and take the top
## `actions_per_month` (difficulty sets it, WP12) as Commands. The operational layer (governors, logistics,
## the defensive military autopilot) runs as before. Numbers: ai_rules. Randomness: the `ai` stream only.


static func rules(state: MatchState) -> AiRulesDef:
	return state.defs.get_def(AiRulesDef.ID) as AiRulesDef


## E11: each AI empire's weights = its species' defaults +-personality_spread, once at match start.
static func roll_personalities(state: MatchState) -> void:
	var r := rules(state)
	if r == null:
		return
	var rng := state.rng(DetRng.AI)
	for eid: int in state.empires.ordered():
		var e: Empire = state.empires.get_or(eid)
		var sd := state.defs.get_def(StringName(e.species)) as SpeciesDef
		if sd == null:
			continue
		for w: String in SpeciesDef.PERSONALITY:
			var base := int(sd.ai_personality.get(StringName(w), 50))
			e.personality[w] = clampi(base + rng.range(-r.personality_spread, r.personality_spread + 1), 0, 100)


## E13: each AI slot's difficulty sets its output bonus and actions a month (match start).
static func apply_difficulty(state: MatchState) -> void:
	for p: Dictionary in state.settings.players:
		if p["controller"] != "ai":
			continue
		var d := state.defs.get_def(StringName(String(p.get("difficulty", MatchSettings.OFFICER)))) as DifficultyDef
		for eid: int in state.empires.ordered():
			var e: Empire = state.empires.get_or(eid)
			if e.player_slot == int(p["slot"]) and d != null:
				e.ai_actions = d.actions
				e.ai_output = d.output_permille


static func month_tick(state: MatchState) -> void:
	var r := rules(state)
	if r == null:
		return
	for eid: int in state.empires.ordered():
		if Autopilot.is_ai(state, eid):
			_think(state, eid, r)


## Scores every candidate and acts on the best `actions_per_month` (ties: candidate order).
static func _think(state: MatchState, eid: int, r: AiRulesDef) -> void:
	var cands := []  # [utility, order, type_id, payload]
	_peace_candidates(state, eid, r, cands)
	_war_candidates(state, eid, r, cands)
	_treaty_candidates(state, eid, r, cands)
	_claim_candidates(state, eid, r, cands)
	_council_candidates(state, eid, r, cands)
	_protectorate_candidates(state, eid, r, cands)
	for i in cands.size():
		cands[i][1] = i
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var done := 0
	for c: Array in cands:
		if done >= actions_for(state, eid, r):
			break
		if int(c[0]) <= 0:
			break
		if Autopilot._do(state, eid, c[2], c[3]):
			done += 1


## Actions a month: ai_rules, or the empire's difficulty (WP12) when set.
static func actions_for(state: MatchState, eid: int, r: AiRulesDef) -> int:
	var e := state.empire(eid)
	return e.ai_actions if e.ai_actions > 0 else r.actions_per_month


static func _p(state: MatchState, eid: int, w: String) -> int:
	return Treaties.personality(state, eid, w)


static func _contacts(state: MatchState, eid: int) -> Array[int]:
	var out: Array[int] = []
	for other: int in state.empires.ordered():
		if other != eid and Relations.has_contact(state, eid, other):
			out.append(other)
	return out


## The strongest empire hostile to eid (at war, or disliked) that is stronger than it, or -1.
static func _threat(state: MatchState, eid: int) -> int:
	var best := -1
	for other in _contacts(state, eid):
		var hostile := state.wars.has(Battles.war_key(eid, other)) or Relations.opinion(state, eid, other) <= -20
		if hostile and Treaties.power(state, other) > Treaties.power(state, eid) \
				and (best < 0 or Treaties.power(state, other) > Treaties.power(state, best)):
			best = other
	return best


# --- candidates ---

static func _treaty_candidates(state: MatchState, eid: int, r: AiRulesDef, out: Array) -> void:
	var threatened := _threat(state, eid) >= 0
	for other in _contacts(state, eid):
		if state.wars.has(Battles.war_key(eid, other)):
			continue
		for def in state.defs.defs("treaty"):
			var d: TreatyDef = def
			if d.has("protectorate") or Treaties.check_propose(state, eid, other, String(d.id)) != "":
				continue
			var acc := Treaties.acceptance(state, eid, other, String(d.id))
			if acc["blocked"] != "" or int(acc["total"]) < 0:
				continue  # they would say no (players are asked anyway only when the score allows it)
			var weight: int
			if d.has("no_war"):
				weight = _p(state, eid, "caution")
			elif d.has("trade"):
				weight = _p(state, eid, "greed")
			elif d.has("access"):
				weight = _p(state, eid, "aggression") / 2
			else:
				weight = _p(state, eid, "xenophilia") + (r.treaty_threat_bonus * 5 if threatened else 0)
			out.append([FixedMath.floor_div(weight, r.treaty_divisor) + FixedMath.floor_div(int(acc["total"]), 4), 0,
				CmdProposeTreaty.TYPE, {"to": other, "treaty": String(d.id)}])


static func _war_candidates(state: MatchState, eid: int, r: AiRulesDef, out: Array) -> void:
	if state.tick < r.peace_years * Calendar.HOURS_PER_YEAR:
		return  # E16: no AI wars in the first years
	var mine := Treaties.power(state, eid)
	var need := r.war_ratio_base + _p(state, eid, "caution") * r.war_ratio_per_caution
	for other in _contacts(state, eid):
		if state.wars.has(Battles.war_key(eid, other)) or Treaties.check_war(state, eid, other) != "":
			continue
		if Treaties.allied(state, eid, other) or Treaties._lanes_between(state, eid, other) > r.war_lanes:
			continue
		var e := state.empire(other)
		if SignatureMechanics.of(state, e) is LegendMechanic and LegendMechanic.fear(e) >= SignatureMechanics.rules(state).fear_deterrence \
				and _p(state, eid, "caution") >= SignatureMechanics.rules(state).fear_deterrence_caution:
			continue  # E14: Fear 300 deters cautious AIs
		var theirs := maxi(1, Treaties.power(state, other))
		var ratio := FixedMath.floor_div(mine * 1000, theirs)
		if ratio < need:
			continue
		var cbs := Wars.casus_belli(state, eid, other)
		var cb := String(cbs[0]) if not cbs.is_empty() else ""
		if cb == "" and _p(state, eid, "aggression") < r.war_no_cb_aggression:
			continue
		var opportunity := 0
		for w: int in state.war_info.ordered():
			var war: War = state.war_info.get_or(w)
			if (war.attacker == other or war.defender == other) and war.attacker != eid and war.defender != eid:
				opportunity = r.war_opportunity_bonus
		var u := FixedMath.floor_div((ratio - need) * _p(state, eid, "aggression"), 5000) + (r.war_cb_bonus if cb != "" else 0) + opportunity
		u -= FixedMath.floor_div(Relations.opinion(state, eid, other), 4)
		out.append([u, 0, CmdDeclareWar.TYPE, {"empire": other, "casus_belli": cb}])


static func _peace_candidates(state: MatchState, eid: int, r: AiRulesDef, out: Array) -> void:
	var e := state.empire(eid)
	for wid: int in state.war_info.ordered():
		var w: War = state.war_info.get_or(wid)
		if w.attacker != eid and w.defender != eid:
			continue
		var enemy := w.defender if w.attacker == eid else w.attacker
		var score := w.score_of(eid)
		if score >= r.peace_winning_score:
			var terms := _demands(state, w, eid, enemy, score)
			if not terms.is_empty() and (e.war_exhaustion >= r.peace_exhaustion / 2 or score >= r.peace_winning_score * 3):
				out.append([r.peace_utility, 0, CmdOfferPeace.TYPE, {"empire": enemy, "loser": enemy, "terms": terms}])
		elif score <= r.peace_losing_score or e.war_exhaustion >= r.peace_exhaustion:
			out.append([r.peace_utility, 0, CmdOfferPeace.TYPE, {"empire": enemy, "loser": eid, "terms": [{"type": "white"}]}])


## What a winning AI asks for: its war goals first, within what the war score buys.
static func _demands(state: MatchState, w: War, me: int, enemy: int, score: int) -> Array:
	var terms := []
	var allowed := Wars.allowed_terms(state, w, me)
	var budget := score + FixedMath.floor_div(state.empire(enemy).war_exhaustion - state.empire(me).war_exhaustion, 2000)
	if "cede_system" in allowed:
		for sid in Wars.claims_on(state, me, enemy):
			var t := {"type": "cede_system", "ref": sid}
			if Wars.terms_cost(state, terms + [t]) <= budget:
				terms.append(t)
	if "disarmament" in allowed and Wars.terms_cost(state, terms + [{"type": "disarmament"}]) <= budget:
		terms.append({"type": "disarmament"})
	var left := budget - Wars.terms_cost(state, terms)
	var per := Wars.rules(state).reparations_cost
	if left >= per:
		terms.append({"type": "reparations", "amount": FixedMath.floor_div(left * 1000, per)})
	return terms


static func _claim_candidates(state: MatchState, eid: int, r: AiRulesDef, out: Array) -> void:
	if _p(state, eid, "aggression") < r.claim_aggression:
		return
	var e := state.empire(eid)
	if int(e.treasury.get("core:resource/influence", 0)) < (Wars.rules(state).claim_influence + r.claim_influence_cushion) * Stockpile.MILLI:
		return
	for lid: int in state.galaxy.lanes.ordered():
		var lane := state.galaxy.lane(lid)
		for pair: Array in [[lane.a, lane.b], [lane.b, lane.a]]:
			var mine := state.galaxy.system(pair[0])
			var theirs := state.galaxy.system(pair[1])
			if mine.owner != eid or theirs.owner == StateIO.NONE or theirs.owner == eid or state.empire(theirs.owner) == null:
				continue
			if Wars.has_claim(state, eid, pair[1]) or not Relations.has_contact(state, eid, theirs.owner):
				continue
			if Relations.opinion(state, eid, theirs.owner) > r.claim_opinion or theirs.planet_ids.is_empty():
				continue
			if state.galaxy.planet(state.empire(theirs.owner).capital_planet).system_id == pair[1]:
				continue
			out.append([FixedMath.floor_div(_p(state, eid, "aggression"), 10), 0, CmdClaimSystem.TYPE, {"system": pair[1]}])
			return  # one claim a month at most


static func _council_candidates(state: MatchState, eid: int, r: AiRulesDef, out: Array) -> void:
	if not Councils.is_member(state, eid) or _p(state, eid, "ambition") < r.council_ambition:
		return
	var u := FixedMath.floor_div(_p(state, eid, "ambition"), 5)
	var worst := -1
	for other in _contacts(state, eid):
		if Relations.opinion(state, eid, other) <= r.sanction_opinion and Councils.in_force(state, "sanctions", other).is_empty() \
				and (worst < 0 or Relations.opinion(state, eid, other) < Relations.opinion(state, eid, worst)):
			worst = other
	if worst >= 0:
		out.append([u, 0, CmdCouncilPropose.TYPE, {"resolution": "core:resolution/sanctions", "target": worst, "repeal": -1}])
	for other in _contacts(state, eid):
		if not Councils.is_member(state, other) and Relations.opinion(state, eid, other) >= 20:
			out.append([u, 0, CmdCouncilPropose.TYPE, {"resolution": "core:resolution/recognition", "target": other, "repeal": -1}])
			break
	if _p(state, eid, "greed") >= 60:
		out.append([u - 1, 0, CmdCouncilPropose.TYPE, {"resolution": "core:resolution/trade_standards", "target": -1, "repeal": -1}])
	if _p(state, eid, "caution") >= 60 and Pirates.raiders_hunting(state, eid) > 0:
		out.append([u - 1, 0, CmdCouncilPropose.TYPE, {"resolution": "core:resolution/pirate_suppression", "target": -1, "repeal": -1}])


## E8: a threatened empire asks for protection: humans with Respect 300 first (E14), then the most liked.
static func _protectorate_candidates(state: MatchState, eid: int, r: AiRulesDef, out: Array) -> void:
	var best := -1
	var best_key := -1000000
	for other in _contacts(state, eid):
		if Treaties.check_propose(state, eid, other, "core:treaty/protectorate") != "":
			continue
		if not Treaties.accepts(state, eid, other, "core:treaty/protectorate"):
			continue
		var key := Relations.opinion(state, eid, other)
		var o := state.empire(other)
		if SignatureMechanics.of(state, o) is LegendMechanic and LegendMechanic.respect(o) >= SignatureMechanics.rules(state).respect_first_pick:
			key += 1000  # E14: humans with Respect 300 get the first pick
		if key > best_key:
			best = other
			best_key = key
	if best >= 0:
		out.append([r.protectorate_utility, 0, CmdProposeTreaty.TYPE, {"to": best, "treaty": "core:treaty/protectorate"}])
