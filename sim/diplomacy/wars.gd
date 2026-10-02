class_name Wars
extends RefCounted
## War (Sub-spec E7; M4 WP6, owner decisions 2026-10-02): claims and casus belli, declarations (with the
## no-casus-belli penalties), war score from battles, convoy raids and blockades, war exhaustion, and peace
## with terms (white peace, ceded claimed systems, reparations as monthly credits, humiliation, disarmament
## as a fleet value cap). `MatchState.wars` stays the fast hostility set; `MatchState.war_info` holds a War
## record per pair.

const TERMS: Array[String] = ["white", "cede_system", "reparations", "humiliation", "disarmament"]


static func rules(state: MatchState) -> DiplomacyRulesDef:
	return Relations.rules(state)


static func war_of(state: MatchState, a: int, b: int) -> War:
	for wid: int in state.war_info.ordered():
		var w: War = state.war_info.get_or(wid)
		if (w.attacker == a and w.defender == b) or (w.attacker == b and w.defender == a):
			return w
	return null


# --- claims and casus belli ---

static func claim_key(eid: int, sid: int) -> String:
	return "%d:%d" % [eid, sid]


static func has_claim(state: MatchState, eid: int, sid: int) -> bool:
	return state.claims.has(claim_key(eid, sid))


## Systems `eid` claims that `target` owns, in ID order.
static func claims_on(state: MatchState, eid: int, target: int) -> Array[int]:
	var out: Array[int] = []
	for k: String in IdMap.sort_keys(state.claims.keys()):
		if int(k.get_slice(":", 0)) == eid:
			var sid := int(k.get_slice(":", 1))
			if state.galaxy.system(sid).owner == target:
				out.append(sid)
	return out


## E7 casus belli `attacker` holds against `target` now, in a fixed order.
static func casus_belli(state: MatchState, attacker: int, target: int) -> Array[String]:
	var out: Array[String] = []
	if not claims_on(state, attacker, target).is_empty():
		out.append("claim")
	var rel := Relations.of(state, attacker, target)
	if rel != null and (rel.events.has("treaty_broken") or rel.events.has("deal_failed")):
		out.append("retaliation")  # they broke a treaty or failed a deal with us (decays away with the memory)
	for tid: int in state.treaties.ordered():
		var t: Treaty = state.treaties.get_or(tid)
		if Treaties.def_of(state, t.def_id).has("protectorate") and t.b == attacker and state.wars.has(Battles.war_key(t.a, target)):
			out.append("protectorate")
			break
	if Treaties.power(state, target) * 1000 >= maxi(1, Treaties.power(state, attacker)) * rules(state).containment_ratio:
		out.append("containment")
	return out


## Terms a side may demand: from its casus belli (attacker) or reparations and humiliation (anyone).
static func allowed_terms(state: MatchState, w: War, demander: int) -> Array[String]:
	var out: Array[String] = ["white", "reparations", "humiliation"]
	if demander == w.attacker:
		match w.casus_belli:
			"claim":
				out.append("cede_system")
			"containment":
				out.append("disarmament")
	return out


# --- declaring ---

## Starts the war. Without a casus belli: Reputation and everyone's opinion suffer and allies aren't called
## (E7). The defender's partners are called to arms (WP4) and both sides note their pre-war fleet value.
static func declare(state: MatchState, attacker: int, target: int, cb: String) -> War:
	var r := rules(state)
	state.wars[Battles.war_key(attacker, target)] = true
	var w := War.new()
	w.id = state.alloc_id()
	w.attacker = attacker
	w.defender = target
	w.start_tick = state.tick
	w.casus_belli = cb
	state.war_info.put(w.id, w)
	for eid: int in [attacker, target]:
		var e := state.empire(eid)
		if e.prewar_fleet <= 0:
			e.prewar_fleet = maxi(1, Treaties.power(state, eid))
	if cb == "":
		Relations.change_reputation(state, attacker, r.no_cb_reputation)
		for other: int in state.empires.ordered():
			if other != attacker and Relations.has_contact(state, other, attacker):
				Relations.add_event(state, other, attacker, "warmonger", r.no_cb_opinion)
	Treaties.on_war_declared(state, attacker, target, cb != "")
	return w


# --- war score ---

## A12 battle: each empire scores against each enemy it was at war with, for that enemy's ships destroyed or
## captured, weighted by its share of its side's damage (score_battle_cost of battle value per point).
static func battle_resolved(state: MatchState, b: Battle) -> void:
	var r := rules(state)
	var dmg := {}
	var side_dmg := [0, 0]
	for cid: String in IdMap.sort_keys(b.log["dmg"].keys()):
		var n: Variant = b.log["names"].get(cid)
		if n == null:
			continue
		var o := int(n[0])
		var s := b.side_of_owner(o)
		if s >= 0:
			dmg[o] = int(dmg.get(o, 0)) + int(b.log["dmg"][cid])
			side_dmg[s] += int(b.log["dmg"][cid])
	var lost_by := {}  # owner -> battle value lost (destroyed or captured)
	for l: Array in b.log["lost"]:
		var n: Variant = b.log["names"].get(str(l[1]))
		if n != null:
			lost_by[int(n[0])] = int(lost_by.get(int(n[0]), 0)) + int(l[3])
	for c: Array in b.log["captured"]:
		var n: Variant = b.log["names"].get(str(c[1]))
		if n != null:
			lost_by[int(n[0])] = int(lost_by.get(int(n[0]), 0)) + int(c[3])
	for victim: int in IdMap.sort_keys(lost_by.keys()):
		var vs := b.side_of_owner(victim)
		if vs < 0:
			continue
		_exhaust_losses(state, victim, int(lost_by[victim]))
		for scorer: int in b.sides[1 - vs]:
			var w := war_of(state, scorer, victim)
			if w == null or side_dmg[1 - vs] <= 0:
				continue
			var share := FixedMath.floor_div(int(dmg.get(scorer, 0)) * 1000, side_dmg[1 - vs])
			w.add_score(scorer, FixedMath.floor_div(int(lost_by[victim]) * share, r.score_battle_cost))


## E7: +1 per 5% of the pre-war fleet value lost (exhaustion in milli-points).
static func _exhaust_losses(state: MatchState, eid: int, lost: int) -> void:
	var e := state.empire(eid) if eid >= 0 else null
	if e == null or e.prewar_fleet <= 0:
		return
	var r := rules(state)
	var gain := FixedMath.floor_div(lost * 1000 * 1000, e.prewar_fleet * r.exhaustion_loss_step)
	exhaust(state, eid, gain)


## War exhaustion gain (milli-points), scaled by species traits (Reluctant Warriors +50%).
static func exhaust(state: MatchState, eid: int, milli: int) -> void:
	var e := state.empire(eid)
	var scaled := FixedMath.mul_permille(milli, 1000 + SpeciesTraits.empire_permille(state, eid, "empire.war_exhaustion"))
	scaled = FixedMath.mul_permille(scaled, WarFooting.exhaustion_factor(state, eid))  # D7 Total War
	e.war_exhaustion = clampi(e.war_exhaustion + scaled, 0, 100000)


## E7: +1 per score_convoy_value of cargo destroyed by the raider's fleet.
static func convoy_raided(state: MatchState, raider: int, victim: int, cargo: Dictionary) -> void:
	var w := war_of(state, raider, victim)
	if w == null:
		return
	var v := 0
	for res: String in IdMap.sort_keys(cargo.keys()):
		var rd := state.defs.get_def(StringName(res)) as ResourceDef
		if rd != null:
			v += FixedMath.floor_div(int(cargo[res]) * rd.base_value, 1000)
	w.add_score(raider, FixedMath.floor_div(v, rules(state).score_convoy_value))


static func month_tick(state: MatchState) -> void:
	if state.defs == null or rules(state) == null:
		return
	var r := rules(state)
	# Blockades (E7): own stationary warships in an enemy system with none of theirs, +1 a month each (max 10).
	var present := {}  # "owner:system" -> true
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.kind == "warship" and not u.is_moving():
			present["%d:%d" % [u.owner, u.system_id]] = true
	for wid: int in state.war_info.ordered():
		var w: War = state.war_info.get_or(wid)
		for pair: Array in [[w.attacker, w.defender], [w.defender, w.attacker]]:
			var n := 0
			for k: String in IdMap.sort_keys(present.keys()):
				if int(k.get_slice(":", 0)) != pair[0]:
					continue
				var sid := int(k.get_slice(":", 1))
				if state.galaxy.system(sid).owner == pair[1] and not present.has("%d:%d" % [pair[1], sid]):
					n += 1
			w.add_score(pair[0], mini(n, r.blockade_max) * 1000)
	# Exhaustion: recovers at peace; 100 for forced_peace_months forces a status quo peace (E7).
	for eid: int in state.empires.ordered():
		var e: Empire = state.empires.get_or(eid)
		var at_war := false
		for wid: int in state.war_info.ordered():
			var w: War = state.war_info.get_or(wid)
			if w.attacker == eid or w.defender == eid:
				at_war = true
		if not at_war:
			e.war_exhaustion = maxi(0, e.war_exhaustion - r.exhaustion_peace_recovery * 1000)
			e.prewar_fleet = 0
			e.exhausted_since = -1
		elif e.war_exhaustion >= 100000:
			if e.exhausted_since < 0:
				e.exhausted_since = state.tick
			elif state.tick - e.exhausted_since >= r.forced_peace_months * Calendar.HOURS_PER_MONTH:
				for wid: int in state.war_info.ordered():
					var w: War = state.war_info.get_or(wid)
					if w.attacker == eid or w.defender == eid:
						make_peace(state, w, eid, [])
				e.exhausted_since = -1
		else:
			e.exhausted_since = -1
	for pid: int in state.peace_offers.ordered():
		if state.tick >= (state.peace_offers.get_or(pid) as PeaceOffer).expires_tick:
			state.peace_offers.erase(pid)


## E7 stability effect of exhaustion (empire-wide).
static func stability_penalty(state: MatchState, eid: int) -> int:
	var r := rules(state)
	var e := state.empire(eid)
	if e == null or r == null:
		return 0
	if e.war_exhaustion >= 75000:
		return r.exhaustion_stability_75
	if e.war_exhaustion >= 50000:
		return r.exhaustion_stability_50
	return 0


# --- peace ---

## "" if these terms are valid for this war, given by `loser` and demanded by the other side, else why.
static func check_terms(state: MatchState, w: War, loser: int, terms: Array) -> String:
	var demander := w.attacker if loser == w.defender else w.defender
	var allowed := allowed_terms(state, w, demander)
	for t: Variant in terms:
		if not t is Dictionary or not String(t.get("type", "")) in TERMS:
			return "unknown term"
		if not String(t["type"]) in allowed:
			return "%s isn't a goal of this war" % t["type"]
		if t["type"] == "cede_system":
			var sid := int(t.get("ref", -1))
			if state.galaxy.system(sid) == null or state.galaxy.system(sid).owner != loser or not has_claim(state, demander, sid):
				return "only claimed systems of the loser can be ceded"
		if t["type"] == "reparations" and int(t.get("amount", 0)) <= 0:
			return "reparations need an amount"
	return ""


## E7 war score cost of the terms.
static func terms_cost(state: MatchState, terms: Array) -> int:
	var r := rules(state)
	var cost := 0
	for t: Dictionary in terms:
		match String(t["type"]):
			"cede_system":
				var v := maxi(r.system_min_value, Deals.system_output(state, int(t["ref"])) * r.system_value_months)
				cost += clampi(r.cede_cost_min + FixedMath.floor_div(v, r.cede_value_per_point), r.cede_cost_min, r.cede_cost_max)
			"reparations":
				cost += FixedMath.floor_div(int(t["amount"]) * r.reparations_cost, 1000)
			"humiliation":
				cost += r.humiliation_cost
			"disarmament":
				cost += r.disarmament_cost
	return cost


## E7: the AI loser accepts if cost <= the demander's war score + (its own exhaustion - the demander's) / 2.
static func accepts(state: MatchState, w: War, loser: int, terms: Array) -> bool:
	var demander := w.attacker if loser == w.defender else w.defender
	var limit := w.score_of(demander) + FixedMath.floor_div(state.empire(loser).war_exhaustion - state.empire(demander).war_exhaustion, 2000)
	return terms_cost(state, terms) <= maxi(0, limit)


## An AI winner offered terms by the loser: takes them when they are worth at least what it could demand.
static func accepts_offer(state: MatchState, w: War, loser: int, terms: Array) -> bool:
	var demander := w.attacker if loser == w.defender else w.defender
	var limit := w.score_of(demander) + FixedMath.floor_div(state.empire(loser).war_exhaustion - state.empire(demander).war_exhaustion, 2000)
	return terms_cost(state, terms) >= limit


## Ends the war with the loser giving the terms; both sides remember the war (opinion recovering from -50).
static func make_peace(state: MatchState, w: War, loser: int, terms: Array) -> void:
	var r := rules(state)
	var winner := w.attacker if loser == w.defender else w.defender
	state.wars.erase(Battles.war_key(w.attacker, w.defender))
	state.war_info.erase(w.id)
	for cid: int in state.calls.ordered():
		var c: CallToArms = state.calls.get_or(cid)
		if (c.from == loser and c.enemy == winner) or (c.from == winner and c.enemy == loser):
			state.calls.erase(cid)
	for t: Dictionary in terms:
		match String(t["type"]):
			"cede_system":
				Deals.transfer_system(state, int(t["ref"]), loser, winner)
				state.claims.erase(claim_key(winner, int(t["ref"])))
			"reparations":
				var monthly := maxi(1, FixedMath.floor_div(int(t["amount"]), r.reparations_months))
				Deals.execute(state, loser, winner, [{"giver": loser, "kind": "credits", "ref": "", "amount": monthly,
					"months": r.reparations_months}])
			"humiliation":
				var e := state.empire(loser)
				e.treasury["core:resource/influence"] = maxi(0, int(e.treasury.get("core:resource/influence", 0)) - r.humiliation_influence * Stockpile.MILLI)
				Relations.add_event(state, loser, winner, "humiliated", int(r.event_cap.get(&"humiliated", -40)))
			"disarmament":
				var e := state.empire(loser)
				e.disarm_until = state.tick + r.disarmament_years * Calendar.HOURS_PER_YEAR
				e.disarm_cap = FixedMath.floor_div(Treaties.power(state, loser), 2)
	for pair: Array in [[w.attacker, w.defender], [w.defender, w.attacker]]:
		Relations.add_event(state, pair[0], pair[1], "war_memory", r.war_opinion_cap)


## Disarmament: "" if `eid` may add a warship worth `value` (queued ones count), else why.
static func check_disarmament(state: MatchState, eid: int, value: int) -> String:
	var e := state.empire(eid)
	if e == null or e.disarm_until <= state.tick:
		return ""
	var queued := 0
	for sid: int in state.stations.ordered():
		var st: Station = state.stations.get_or(sid)
		if st.owner == eid:
			for q: Construction in st.ship_queue:
				if q.design != 0:
					queued += _cost_value(state, q.cost)
	if Treaties.power(state, eid) + queued + value > e.disarm_cap:
		return "disarmed: the fleet is capped at %d until the treaty runs out" % e.disarm_cap
	return ""


static func _cost_value(state: MatchState, cost: Dictionary) -> int:
	var v := 0
	for res: Variant in cost:
		var rd := state.defs.get_def(StringName(res)) as ResourceDef
		v += int(cost[res]) * (rd.base_value if rd else 1000)
	return FixedMath.floor_div(v, 1000)
