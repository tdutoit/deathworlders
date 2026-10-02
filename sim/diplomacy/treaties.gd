class_name Treaties
extends RefCounted
## Treaties (Sub-spec E3-E5, E8; M4 WP4): the E5 acceptance score with its breakdown, signing, notice and
## breaking, calls to arms, protectorate tribute and obligation, and the monthly trust from honoured treaties.
## State: MatchState.treaties, .proposals and .calls (IdMaps). Numbers: diplomacy_rules and treaty Defs.


static func rules(state: MatchState) -> DiplomacyRulesDef:
	return Relations.rules(state)


static func def_of(state: MatchState, def_id: String) -> TreatyDef:
	return state.defs.get_def(StringName(def_id)) as TreatyDef


## Active treaties between two empires (either direction), in ID order; `def_id` filters.
static func between(state: MatchState, a: int, b: int, def_id := "") -> Array[Treaty]:
	var out: Array[Treaty] = []
	for tid: int in state.treaties.ordered():
		var t: Treaty = state.treaties.get_or(tid)
		if ((t.a == a and t.b == b) or (t.a == b and t.b == a)) and (def_id == "" or t.def_id == def_id):
			out.append(t)
	return out


static func has_effect(state: MatchState, a: int, b: int, effect: String) -> bool:
	for t in between(state, a, b):
		if def_of(state, t.def_id).has(effect):
			return true
	return false


## Defence pact, alliance or protectorate: partners who answer calls to arms and fight on one side.
static func allied(state: MatchState, a: int, b: int) -> bool:
	return has_effect(state, a, b, "call_to_arms") or has_effect(state, a, b, "protectorate")


## Battle value of the empire's warships (E5 fear, E8 protectorate gate; full visibility in M4).
static func power(state: MatchState, eid: int) -> int:
	var scratch := state.scratch()
	var key := "power:%d" % eid
	if not scratch.has(key):
		var total := 0
		for uid: int in state.units.ordered():
			var u: Unit = state.units.get_or(uid)
			if u.owner == eid and u.kind == "warship":
				total += Battles.cost_of(state, u.id)
		scratch[key] = total
	return scratch[key]


## E11 weight of an empire (species defaults; WP10 adds per-empire variation).
static func personality(state: MatchState, eid: int, weight: String) -> int:
	var sd := state.defs.get_def(StringName(state.empire(eid).species)) as SpeciesDef
	return int(sd.ai_personality.get(StringName(weight), 50)) if sd != null else 50


## "" if `from` may propose this treaty to `to` (contact, peace, not already signed, influence, protectorate
## conditions), else the reason (loc-free; the UI shows its own keys).
static func check_propose(state: MatchState, from: int, to: int, def_id: String) -> String:
	var d := def_of(state, def_id)
	if d == null:
		return "unknown treaty %s" % def_id
	if from == to or state.empire(to) == null:
		return "not another empire"
	if not Relations.has_contact(state, from, to):
		return "no contact yet"
	if state.wars.has(Battles.war_key(from, to)):
		return "at war"
	if not between(state, from, to, def_id).is_empty():
		return "already signed"
	if int(state.empire(from).treasury.get("core:resource/influence", 0)) < d.influence * Stockpile.MILLI:
		return "needs %d influence" % d.influence
	if d.has("protectorate"):
		var reason := check_protectorate(state, from, to)
		if reason != "":
			return reason
	return ""


## E8 adapted (owner decision 2026-10-02): the protected (`from`) has under protectorate_power permille of a
## hostile neighbour's power (at war with it, or its opinion of it at most protectorate_hostile_opinion), the
## guardian is within protectorate_lanes, and the protected's own view of the guardian is at least the
## treaty's min_opinion.
static func check_protectorate(state: MatchState, from: int, to: int) -> String:
	var r := rules(state)
	if Relations.opinion(state, from, to) < def_of(state, "core:treaty/protectorate").min_opinion:
		return "the protected must think well of its guardian"
	var threatened := false
	for other: int in state.empires.ordered():
		if other == from or other == to or not Relations.has_contact(state, from, other):
			continue
		var hostile := state.wars.has(Battles.war_key(from, other)) or Relations.opinion(state, from, other) <= r.protectorate_hostile_opinion
		if hostile and power(state, from) * 1000 < power(state, other) * r.protectorate_power:
			threatened = true
			break
	if not threatened:
		return "only an empire threatened by a much stronger neighbour can ask for protection"
	if _lanes_between(state, from, to) > r.protectorate_lanes:
		return "the guardian is too far away"
	return ""


static func _lanes_between(state: MatchState, a: int, b: int) -> int:
	var best := Sectors.FAR
	var cache := {}
	for sid: int in state.galaxy.systems.ordered():
		if state.galaxy.system(sid).owner != a:
			continue
		var near := AutoLogistics.hops_within(state, sid, rules(state).protectorate_lanes, cache)
		for other: int in near:
			if state.galaxy.system(other).owner == b:
				best = mini(best, int(near[other]))
	return best


## E5 acceptance of `to` for a treaty proposed by `from`: {"total", "parts": [[loc key, value], ...],
## "blocked": loc key of a failed E4 gate or ""}. Accepted when not blocked and total >= 0.
static func acceptance(state: MatchState, from: int, to: int, def_id: String, items: Array = []) -> Dictionary:
	var r := rules(state)
	var d := def_of(state, def_id) if def_id != "" else null  # no treaty: a plain deal (threshold 0, trade-minded)
	var op := Relations.opinion(state, to, from)
	var tr := Relations.trust(state, to, from)
	var parts := [["ACCEPT_OPINION", op / 2], ["ACCEPT_TRUST", tr / 2]]
	if d != null:
		parts.append(["ACCEPT_THRESHOLD", -d.threshold])
	if not items.is_empty():
		parts.append(["ACCEPT_DEAL", Deals.balance_points(state, to, items)])
	var rel := Relations.of(state, to, from)
	if rel != null and rel.standing.has("common_enemy"):
		parts.append(["ACCEPT_SHARED_THREAT", r.shared_threat])
	var p_to := maxi(1, power(state, to))
	var ratio := FixedMath.floor_div(power(state, from) * 1000, p_to)
	var fear := clampi(FixedMath.floor_div(ratio - 1000, maxi(1, r.fear_ratio_step)), 0, r.fear_max)
	if fear > 0:
		parts.append(["ACCEPT_FEAR", fear])
	var pers := FixedMath.floor_div(personality(state, to, "xenophilia") - 50, 5)
	var kind := d.kind if d != null else &"trade"
	if kind == &"defensive":
		pers += FixedMath.floor_div(personality(state, to, "honour") - 50, 10)
	elif kind == &"trade":
		pers -= FixedMath.floor_div(personality(state, to, "greed") - 50, 5)
	parts.append(["ACCEPT_PERSONALITY", pers])
	if rel != null and int(rel.refusals.get(def_id, -1)) >= 0 \
			and state.tick - int(rel.refusals[def_id]) < r.refusal_months * Calendar.HOURS_PER_MONTH:
		parts.append(["ACCEPT_RECENT_REFUSAL", r.refusal_penalty])
	var total := 0
	for p: Array in parts:
		total += int(p[1])
	var blocked := ""
	if d != null and op < d.min_opinion:
		blocked = "ACCEPT_GATE_OPINION"
	elif d != null and tr < d.min_trust:
		blocked = "ACCEPT_GATE_TRUST"
	return {"total": total, "parts": parts, "blocked": blocked}


static func accepts(state: MatchState, from: int, to: int, def_id: String, items: Array = []) -> bool:
	if def_id == "" and Deals.is_gift(items, from):
		return true  # gifts are always welcome
	var a := acceptance(state, from, to, def_id, items)
	return a["blocked"] == "" and int(a["total"]) >= 0


## Signs the treaty; the proposer pays its influence (E4).
static func sign(state: MatchState, from: int, to: int, def_id: String) -> Treaty:
	var d := def_of(state, def_id)
	var e := state.empire(from)
	e.treasury["core:resource/influence"] = int(e.treasury.get("core:resource/influence", 0)) - d.influence * Stockpile.MILLI
	var t := Treaty.new()
	t.id = state.alloc_id()
	t.def_id = def_id
	t.a = from
	t.b = to
	t.start_tick = state.tick
	state.treaties.put(t.id, t)
	Councils.on_dealing(state, from, to)  # E9 defiance of sanctions
	for eid: int in [from, to]:
		SignatureMechanics.treaty_event(state, eid, {"type": "treaty_signed", "treaty": t.id, "def": def_id})
	return t


## The proposal was refused: remembered for E5's recent-refusal term.
static func refuse(state: MatchState, from: int, to: int, def_id: String) -> void:
	var rel := Relations.of(state, to, from)
	if rel != null:
		rel.refusals[def_id] = state.tick


## Ends a treaty by `by`: cleanly after its minimum duration (with notice where the treaty needs it), else it
## is broken (E3, E4).
static func cancel(state: MatchState, t: Treaty, by: int) -> void:
	var d := def_of(state, t.def_id)
	if state.tick - t.start_tick >= d.min_years * Calendar.HOURS_PER_YEAR:
		if d.notice_months > 0 and t.ends_tick == 0:
			t.ends_tick = state.tick + d.notice_months * Calendar.HOURS_PER_MONTH
		elif t.ends_tick == 0:
			_end(state, t)
	else:
		break_treaty(state, t, by)


## E3/E4 break: the victim's opinion and trust (to 0 where the treaty says), every other empire in contact
## -15 opinion and -20 trust toward the breaker, and Reputation.
static func break_treaty(state: MatchState, t: Treaty, breaker: int) -> void:
	var r := rules(state)
	var d := def_of(state, t.def_id)
	var victim := t.other(breaker)
	Relations.add_event(state, victim, breaker, "treaty_broken", d.break_opinion)
	if d.break_trust_zero:
		Relations.change_trust(state, victim, breaker, -r.trust_max)
	for other: int in state.empires.ordered():
		if other != victim and other != breaker and Relations.has_contact(state, other, breaker):
			Relations.add_event(state, other, breaker, "treaty_broken_other", r.break_others_opinion)
			Relations.change_trust(state, other, breaker, r.break_others_trust)
	Relations.change_reputation(state, breaker, r.break_reputation)
	for eid: int in [breaker, victim]:
		SignatureMechanics.treaty_event(state, eid, {"type": "treaty_broken", "treaty": t.id, "def": t.def_id, "breaker": breaker})
	state.treaties.erase(t.id)


static func _end(state: MatchState, t: Treaty) -> void:
	for eid: int in [t.a, t.b]:
		SignatureMechanics.treaty_event(state, eid, {"type": "treaty_ended", "treaty": t.id, "def": t.def_id})
	state.treaties.erase(t.id)


## "" if `attacker` may declare war on `target` now: a non-aggression pact needs its notice to have run out.
static func check_war(state: MatchState, attacker: int, target: int) -> String:
	for t in between(state, attacker, target):
		if def_of(state, t.def_id).has("no_war") and (t.ends_tick == 0 or state.tick < t.ends_tick):
			return "non-aggression pact: give notice first (%d months)" % def_of(state, t.def_id).notice_months
	return ""


## A war was declared: the declarer breaks its treaties with the target, the target's partners are called to
## arms (not for a war without casus belli: E7 says allies won't join), and an attacked protected starts its
## guardian's response clock.
static func on_war_declared(state: MatchState, attacker: int, target: int, call_allies := true) -> void:
	var r := rules(state)
	for t in between(state, attacker, target):
		break_treaty(state, t, attacker)
	for tid: int in state.treaties.ordered():
		var t: Treaty = state.treaties.get_or(tid)
		if t.a != target and t.b != target:
			continue
		var partner := t.other(target)
		var d := def_of(state, t.def_id)
		if partner == attacker or not (d.has("call_to_arms") or d.has("protectorate")):
			continue
		if d.has("protectorate") and t.a == target and t.attacked_tick < 0:
			t.attacked_tick = state.tick
		if not call_allies or state.wars.has(Battles.war_key(partner, attacker)) or _has_call(state, target, partner, attacker):
			continue
		var c := CallToArms.new()
		c.id = state.alloc_id()
		c.from = target
		c.to = partner
		c.enemy = attacker
		c.tick = state.tick
		c.deadline_tick = state.tick + r.call_days * Calendar.HOURS_PER_DAY
		state.calls.put(c.id, c)
		if Autopilot.is_ai(state, partner):
			# Placeholder until the strategic AI (WP10): answer by Honour on the ai stream.
			answer_call(state, c, state.rng(DetRng.AI).range(0, 100) < personality(state, partner, "honour"))


static func _has_call(state: MatchState, from: int, to: int, enemy: int) -> bool:
	for cid: int in state.calls.ordered():
		var c: CallToArms = state.calls.get_or(cid)
		if c.from == from and c.to == to and c.enemy == enemy:
			return true
	return false


## E3: answering a call joins the war (+trust); refusing it costs trust with the caller.
static func answer_call(state: MatchState, c: CallToArms, join: bool) -> void:
	var r := rules(state)
	state.calls.erase(c.id)
	if join and check_war(state, c.to, c.enemy) == "":
		if not state.wars.has(Battles.war_key(c.to, c.enemy)):
			Wars.declare(state, c.to, c.enemy, "call_to_arms")
		Relations.change_trust(state, c.from, c.to, r.call_answered_trust)
	else:
		Relations.change_trust(state, c.from, c.to, r.call_ignored_trust)


## Standing opinion from active treaties for A's view of B (Relations.month_tick adds these).
static func standing(state: MatchState, a: int, b: int) -> Dictionary:
	var out := {}
	for t in between(state, a, b):
		var d := def_of(state, t.def_id)
		if d.opinion == 0 or (d.has("protectorate") and a != t.a):
			continue  # protectorate: only the protected's view of its guardian (E2)
		out["treaty_" + String(d.id).get_slice("/", 1)] = d.opinion
	return out


static func month_tick(state: MatchState) -> void:
	if state.defs == null or rules(state) == null:
		return
	var r := rules(state)
	# Trust grows with honoured treaties (E3: +1 a month each, at most +3 a month per pair).
	var gains := {}  # "a:b" directed -> trust to add
	for tid: int in state.treaties.ordered():
		var t: Treaty = state.treaties.get_or(tid)
		for pair: Array in [[t.a, t.b], [t.b, t.a]]:
			var k := Relations.key(pair[0], pair[1])
			gains[k] = mini(int(gains.get(k, 0)) + r.trust_per_treaty, r.trust_treaty_max)
	for k: String in IdMap.sort_keys(gains.keys()):
		Relations.change_trust(state, int(k.get_slice(":", 0)), int(k.get_slice(":", 1)), int(gains[k]))
	for tid: int in state.treaties.ordered():
		var t: Treaty = state.treaties.get_or(tid)
		if t.ends_tick > 0 and state.tick >= t.ends_tick:
			_end(state, t)
			continue
		if def_of(state, t.def_id).has("protectorate"):
			_protectorate_month(state, t, r)
	for pid: int in state.proposals.ordered():
		if state.tick >= (state.proposals.get_or(pid) as Proposal).expires_tick:
			state.proposals.erase(pid)
	for cid: int in state.calls.ordered():
		var c: CallToArms = state.calls.get_or(cid)
		if state.tick >= c.deadline_tick:
			answer_call(state, c, false)


## Tribute (a share of the protected's positive credit net) and the guardian's 60-day obligation (E8).
static func _protectorate_month(state: MatchState, t: Treaty, r: DiplomacyRulesDef) -> void:
	var protected := state.empire(t.a)
	var guardian := state.empire(t.b)
	var tribute := FixedMath.mul_permille(maxi(0, protected.credit_net), r.protectorate_tribute)
	var have := int(protected.treasury.get("core:resource/credits", 0))
	tribute = mini(tribute, maxi(0, have))
	protected.treasury["core:resource/credits"] = have - tribute
	guardian.treasury["core:resource/credits"] = int(guardian.treasury.get("core:resource/credits", 0)) + tribute
	if t.attacked_tick < 0:
		return
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner == t.b and u.kind == "warship" and state.galaxy.system(u.system_id).owner == t.a:
			Relations.add_event(state, t.a, t.b, "rescued", int(r.event_cap.get(&"rescued", 0)))
			Relations.change_trust(state, t.a, t.b, r.protectorate_success_trust)
			Relations.change_reputation(state, t.b, r.protectorate_success_reputation)
			t.attacked_tick = -1
			SignatureMechanics.treaty_event(state, t.b, {"type": "protectorate_defended", "treaty": t.id})
			return
	if state.tick - t.attacked_tick > r.protectorate_days * Calendar.HOURS_PER_DAY:
		Relations.change_trust(state, t.a, t.b, -r.trust_max)
		Relations.change_reputation(state, t.b, r.protectorate_fail_reputation)
		SignatureMechanics.treaty_event(state, t.b, {"type": "protectorate_failed", "treaty": t.id})
		_end(state, t)
