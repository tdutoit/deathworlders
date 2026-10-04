class_name Espionage
extends RefCounted
## Espionage, the light layer (main spec 12, D12 agent coverage, E3 "espionage caught"; M5 WP9; owner rules
## 2026-10-04). An empire recruits up to `max_agents` agents (influence, credit upkeep) against empires it has
## contact with; an agent needs `insert_days` to get in place, then rolls each month for success (its mission)
## and for being caught (agent lost, the target's "espionage" opinion event, Reputation). Missions:
## gather_intel (the target's core systems count as covered at `core_strength`; success adds intel points up
## to intel_cap), steal_fragments, sabotage_convoys (one loaded freighter loses its cargo), incite_unrest (the
## target's least stable colony loses stability). Numbers in espionage_rules.

const MISSIONS: Array[String] = ["gather_intel", "steal_fragments", "sabotage_convoys", "incite_unrest"]
const INFLUENCE := "core:resource/influence"
const CREDITS := "core:resource/credits"


static func rules(state: MatchState) -> EspionageRulesDef:
	return state.defs.get_def(EspionageRulesDef.ID) as EspionageRulesDef


static func agents_of(state: MatchState, eid: int) -> Array[Agent]:
	var out: Array[Agent] = []
	for aid: int in state.agents.ordered():
		var a: Agent = state.agents.get_or(aid)
		if a.owner == eid:
			out.append(a)
	return out


static func in_place(state: MatchState, a: Agent) -> bool:
	return state.tick >= a.ready_tick


static func check_recruit(state: MatchState, eid: int, target: int, mission: String) -> String:
	var r := rules(state)
	var e := state.empire(eid)
	if e == null or r == null:
		return "no empire"
	if target == eid or state.empire(target) == null:
		return "not another empire"
	if not Relations.has_contact(state, eid, target):
		return "no contact yet"
	if not mission in MISSIONS:
		return "unknown mission %s" % mission
	if agents_of(state, eid).size() >= r.max_agents:
		return "at most %d agents" % r.max_agents
	if int(e.treasury.get(INFLUENCE, 0)) < r.recruit_influence * Stockpile.MILLI:
		return "needs %d influence" % r.recruit_influence
	return ""


static func recruit(state: MatchState, eid: int, target: int, mission: String) -> Agent:
	var r := rules(state)
	var e := state.empire(eid)
	e.treasury[INFLUENCE] = int(e.treasury.get(INFLUENCE, 0)) - r.recruit_influence * Stockpile.MILLI
	var a := Agent.new()
	a.id = state.alloc_id()
	a.owner = eid
	a.target = target
	a.mission = mission
	a.ready_tick = state.tick + r.insert_days * Calendar.HOURS_PER_DAY
	state.agents.put(a.id, a)
	return a


## The target's core systems (capital system and its neighbours within core_lanes).
static func core_systems(state: MatchState, target: int) -> Array[int]:
	var e := state.empire(target)
	var out: Array[int] = []
	if e == null or e.capital_planet == StateIO.NONE:
		return out
	var cov := {}
	Fog._spread(state, cov, state.galaxy.planet(e.capital_planet).system_id, rules(state).core_lanes, 0)
	for sid: int in IdMap.sort_keys(cov.keys()):
		out.append(sid)
	return out


## Fog source (D12): gather_intel agents in place cover the target's core systems.
static func add_coverage(state: MatchState, eid: int, cov: Dictionary) -> void:
	var r := rules(state)
	if r == null:
		return
	for a in agents_of(state, eid):
		if a.mission == "gather_intel" and in_place(state, a):
			for sid in core_systems(state, a.target):
				Fog._cover(cov, sid, r.core_strength)


## Monthly: upkeep, then each agent in place rolls to be caught, then for success.
static func month_tick(state: MatchState) -> void:
	var r := rules(state)
	if r == null:
		return
	var rng := state.rng(DetRng.EVENTS)
	for aid: int in state.agents.ordered():
		var a: Agent = state.agents.get_or(aid)
		var e := state.empire(a.owner)
		if e == null or state.empire(a.target) == null:
			state.agents.erase(aid)
			continue
		e.treasury[CREDITS] = int(e.treasury.get(CREDITS, 0)) - r.upkeep_credits * Stockpile.MILLI
		if not in_place(state, a):
			continue
		var caught := FixedMath.mul_permille(r.caught_permille, 1000 + SpeciesTraits.empire_permille(state, a.target, "empire.agent_detection"))
		if rng.range(0, 1000) < caught:
			state.agents.erase(aid)
			Relations.add_event(state, a.target, a.owner, "espionage", r.caught_opinion)
			Relations.change_reputation(state, a.owner, r.caught_reputation)
			continue
		var odds := FixedMath.mul_permille(r.success_permille, 1000 + SpeciesTraits.empire_permille(state, a.owner, "empire.agent_success"))
		if rng.range(0, 1000) < odds:
			_succeed(state, a, r, rng)


static func _succeed(state: MatchState, a: Agent, r: EspionageRulesDef, rng: DetRng) -> void:
	match a.mission:
		"gather_intel":
			Intel.gain(state, a.owner, a.target, r.intel_points, r.intel_cap)
		"steal_fragments":
			ReverseEngineering.add_fragments(state, a.owner, state.empire(a.target).species, r.fragments)
		"sabotage_convoys":
			var loaded: Array[Unit] = []
			for uid: int in state.units.ordered():
				var u: Unit = state.units.get_or(uid)
				if u.owner == a.target and u.kind == "freighter" and not u.cargo.is_empty():
					loaded.append(u)
			if not loaded.is_empty():
				loaded[rng.range(0, loaded.size())].cargo.clear()
		"incite_unrest":
			var worst: Colony = null
			for pid: int in state.colonies.ordered():
				var c: Colony = state.colonies.get_or(pid)
				if c.owner == a.target and (worst == null or c.stability < worst.stability):
					worst = c
			if worst != null:
				worst.stability = maxi(0, worst.stability - r.unrest_stability)


## AI (until WP11): one agent gathering intel on its strongest contact, sabotaging convoys while at war.
static func auto(state: MatchState, eid: int) -> void:
	var r := rules(state)
	if r == null or not agents_of(state, eid).is_empty():
		return
	var e := state.empire(eid)
	if int(e.treasury.get(INFLUENCE, 0)) < r.ai_influence_reserve * Stockpile.MILLI:
		return
	var best := StateIO.NONE
	var best_power := -1
	for other: int in state.empires.ordered():
		if other == eid or not Relations.has_contact(state, eid, other):
			continue
		var p := Treaties.power(state, other)
		if state.wars.has(Battles.war_key(eid, other)):
			p += 1000000  # an enemy first
		if p > best_power:
			best = other
			best_power = p
	if best == StateIO.NONE:
		return
	var mission := "sabotage_convoys" if state.wars.has(Battles.war_key(eid, best)) else "gather_intel"
	if check_recruit(state, eid, best, mission) == "":
		recruit(state, eid, best, mission)
