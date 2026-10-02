class_name Relations
extends RefCounted
## Opinion, trust, contact and Reputation (Sub-spec E1-E3, E14; M4 WP3). Relations live in
## MatchState.relations keyed "from:to". Monthly (month phase 5): first contacts, then each relation's
## standing modifiers are recomputed and its event modifiers decay one step when due.

const NONE := 0


static func rules(state: MatchState) -> DiplomacyRulesDef:
	return state.defs.get_def(DiplomacyRulesDef.ID) as DiplomacyRulesDef


static func key(a: int, b: int) -> String:
	return "%d:%d" % [a, b]


## A's view of B, or null before first contact.
static func of(state: MatchState, a: int, b: int) -> Relation:
	return state.relations.get(key(a, b))


static func has_contact(state: MatchState, a: int, b: int) -> bool:
	return state.relations.has(key(a, b))


## Base affinity of A's species toward B's (E2 table).
static func affinity(state: MatchState, a: int, b: int) -> int:
	var sa := state.defs.get_def(StringName(state.empire(a).species)) as SpeciesDef
	return int(sa.affinity.get(StringName(state.empire(b).species), 0)) if sa != null else 0


## E1 opinion of A toward B: affinity + standing + events, clamped, at most war_opinion_cap while at war.
static func opinion(state: MatchState, a: int, b: int) -> int:
	var r := rules(state)
	var total := 0
	for part: Array in breakdown(state, a, b):
		total += int(part[1])
	total = clampi(total, r.opinion_min, r.opinion_max)
	if state.wars.has(Battles.war_key(a, b)):
		total = mini(total, r.war_opinion_cap)
	return total


## [[loc key, value], ...] for the UI's opinion breakdown (E5 shows its terms the same way).
static func breakdown(state: MatchState, a: int, b: int) -> Array:
	var out := [["OPINION_AFFINITY", affinity(state, a, b)]]
	var rel := of(state, a, b)
	if rel == null:
		return out
	for t: String in IdMap.sort_keys(rel.standing.keys()):
		out.append(["OPINION_" + t.to_upper(), int(rel.standing[t])])
	for t: String in IdMap.sort_keys(rel.events.keys()):
		out.append(["OPINION_" + t.to_upper(), int(rel.events[t][0])])
	return out


static func trust(state: MatchState, a: int, b: int) -> int:
	var rel := of(state, a, b)
	return rel.trust if rel != null else 0


## E3 deeds: trust moves only by these.
static func change_trust(state: MatchState, a: int, b: int, delta: int) -> void:
	var rel := of(state, a, b)
	if rel != null:
		rel.trust = clampi(rel.trust + delta, 0, rules(state).trust_max)


## An E2 event modifier on A's view of B: `amount` points (sign = direction), capped by the type's total.
## The decay clock restarts. Pack Bonding (humans): an ally's positive events toward them grow faster.
static func add_event(state: MatchState, a: int, b: int, type: String, amount: int) -> void:
	var rel := of(state, a, b)
	if rel == null or amount == 0:
		return
	if amount > 0 and Treaties.allied(state, a, b):
		amount = FixedMath.mul_permille(amount, 1000 + SpeciesTraits.empire_permille(state, b, "empire.ally_opinion"))  # Pack Bonding
	var cap := int(rules(state).event_cap.get(StringName(type), amount))
	var cur := int(rel.events.get(type, [0, 0])[0])
	var v := cur + amount
	v = mini(v, cap) if cap > 0 else maxi(v, cap)
	if v == 0:
		rel.events.erase(type)
	else:
		rel.events[type] = [v, 0]


## E14 Reputation (every empire), clamped.
static func change_reputation(state: MatchState, eid: int, delta: int) -> void:
	var r := rules(state)
	var e := state.empire(eid)
	if e != null:
		e.reputation = clampi(e.reputation + delta, r.reputation_min, r.reputation_max)


static func month_tick(state: MatchState) -> void:
	if state.defs == null or rules(state) == null:
		return
	_contacts(state)
	var r := rules(state)
	var at_war := {}  # empire -> [enemies]
	for k: String in IdMap.sort_keys(state.wars.keys()):
		var a := int(k.get_slice(":", 0))
		var b := int(k.get_slice(":", 1))
		at_war[a] = at_war.get(a, []) + [b]
		at_war[b] = at_war.get(b, []) + [a]
	var borders := _borders(state)
	for k: String in IdMap.sort_keys(state.relations.keys()):
		var rel: Relation = state.relations[k]
		rel.standing.clear()
		rel.standing.merge(Treaties.standing(state, rel.from, rel.to))  # E2 treaty bonuses (WP4)
		if not Wars.claims_on(state, rel.from, rel.to).is_empty() or not Wars.claims_on(state, rel.to, rel.from).is_empty():
			rel.standing["claims"] = r.opinion_claims  # E2 overlapping claims (WP6)
		var sig := SignatureMechanics.opinion_from(state, rel.to, rel.from)
		if sig != 0:
			rel.standing["signature"] = sig  # Legend (Respect / Fear) or Sanctuary (WP9)
		var sanction := Councils.sanctions_standing(state, rel.from, rel.to)
		if sanction != 0:
			rel.standing["sanctions"] = sanction  # E9 Sanctions on X (WP8)
		if borders.has(Battles.war_key(rel.from, rel.to)):
			rel.standing["border"] = r.opinion_border
		for enemy: int in at_war.get(rel.from, []):
			if enemy != rel.to and enemy in at_war.get(rel.to, []):
				rel.standing["common_enemy"] = r.opinion_common_enemy
				break
		for t: String in IdMap.sort_keys(rel.events.keys()):
			var ev: Array = rel.events[t]
			var every := int(r.event_decay_months.get(StringName(t), 0))
			if every <= 0:
				continue
			ev[1] = int(ev[1]) + 1
			if int(ev[1]) >= every:
				ev[0] = int(ev[0]) - signi(int(ev[0]))
				ev[1] = 0
			if int(ev[0]) == 0:
				rel.events.erase(t)


## First contact (owner decision 2026-10-02): an own system within contact_lanes of the other's territory, or
## any own unit in a system the other owns. Contact is mutual.
static func _contacts(state: MatchState) -> void:
	var r := rules(state)
	var empires: Array = state.empires.ordered()
	var owned := {}  # empire -> [systems]
	for sid: int in state.galaxy.systems.ordered():
		var o := state.galaxy.system(sid).owner
		if o != StateIO.NONE and state.empires.has(o):
			owned[o] = owned.get(o, []) + [sid]
	var met := {}
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner < 0 or not state.empires.has(u.owner):
			continue
		var o := state.galaxy.system(u.system_id).owner
		if o != StateIO.NONE and o != u.owner and state.empires.has(o):
			met[Battles.war_key(u.owner, o)] = true
	var cache := {}
	for i in empires.size():
		for j in range(i + 1, empires.size()):
			var a: int = empires[i]
			var b: int = empires[j]
			if has_contact(state, a, b):
				continue
			var k := Battles.war_key(a, b)
			if not met.has(k):
				for sid: int in owned.get(a, []):
					var near := AutoLogistics.hops_within(state, sid, r.contact_lanes, cache)
					if (owned.get(b, []) as Array).any(func(x: int) -> bool: return near.has(x)):
						met[k] = true
						break
			if met.has(k):
				_meet(state, a, b)
				_meet(state, b, a)


static func _meet(state: MatchState, a: int, b: int) -> void:
	var r := rules(state)
	var rel := Relation.new()
	rel.from = a
	rel.to = b
	rel.contact_tick = state.tick
	rel.trust = r.trust_start_wary if affinity(state, a, b) <= r.wary_affinity else r.trust_start
	state.relations[key(a, b)] = rel


## {"a:b" (lower first): true} for empire pairs with an own system one lane from the other's (shared border).
static func _borders(state: MatchState) -> Dictionary:
	var out := {}
	for lid: int in state.galaxy.lanes.ordered():
		var lane := state.galaxy.lane(lid)
		var oa := state.galaxy.system(lane.a).owner
		var ob := state.galaxy.system(lane.b).owner
		if oa != StateIO.NONE and ob != StateIO.NONE and oa != ob:
			out[Battles.war_key(oa, ob)] = true
	return out
