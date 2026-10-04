class_name Research
extends RefCounted
## Empire research (main spec 8, Sub-spec B14; M5 WP2). Research points pile up in the treasury from jobs and
## buildings; on the month tick each empire spends all of them on the first researchable techs of its queue,
## split evenly over its slots (research_rules.slots + empire.research_slots), boosted by empire.research.
## A tech completes when its progress reaches its cost (pace and tech.cost applied); the overflow goes back to
## the treasury. Researched techs apply their modifiers through SpeciesTraits (the empire's modifier source)
## and unlock every Def whose requires_tech they complete.

const RES := "core:resource/research"
const MAX_QUEUE := 40


static func rules(state: MatchState) -> ResearchRulesDef:
	return state.defs.get_def(ResearchRulesDef.ID) as ResearchRulesDef


static func has_tech(state: MatchState, eid: int, tech: String) -> bool:
	var e := state.empire(eid)
	return e != null and e.techs.has(tech)


## True when the empire has every tech in `reqs` (pirates and nobody have none; an empty list is free).
static func has_all(state: MatchState, eid: int, reqs: Array) -> bool:
	if reqs.is_empty():
		return true
	var e := state.empire(eid) if eid >= 0 else null
	if e == null:
		return false
	for t: Variant in reqs:
		if not e.techs.has(String(t)):
			return false
	return true


## The first missing tech of `reqs` as a reason string for BuildRules and friends, or "".
static func missing(state: MatchState, eid: int, reqs: Array) -> String:
	if has_all(state, eid, reqs):
		return ""
	var e := state.empire(eid) if eid >= 0 else null
	for t: Variant in reqs:
		if e == null or not e.techs.has(String(t)):
			return "needs tech %s" % t
	return ""


## Why the empire may never research this tech this match ("" = it may, now or later).
static func blocked(state: MatchState, eid: int, tech: String) -> String:
	var e := state.empire(eid)
	var t := state.defs.get_def(StringName(tech)) as TechDef
	if e == null or t == null:
		return "unknown tech %s" % tech
	if e.techs.has(tech):
		return "already researched"
	if not t.species_only.is_empty() and not StringName(e.species) in t.species_only:
		return "not for this species"
	for x in t.exclusive_with:
		if e.techs.has(String(x)):
			return "locked by %s" % x
	return ""


## Why the empire can't put research into this tech right now ("" = it can).
static func not_ready(state: MatchState, eid: int, tech: String) -> String:
	var why := blocked(state, eid, tech)
	if why != "":
		return why
	var e := state.empire(eid)
	var t := state.defs.get_def(StringName(tech)) as TechDef
	for p in t.prereqs:
		if not e.techs.has(String(p)):
			return "needs %s" % p
	if t.tier > 1:
		var need := rules(state).tier_prereqs
		var have := 0
		for done: String in e.techs:
			var d := state.defs.get_def(StringName(done)) as TechDef
			if d != null and d.branch == t.branch and d.tier == t.tier - 1:
				have += 1
		if have < need:
			return "needs %d tier-%d %s techs (%d)" % [need, t.tier - 1, t.branch, have]
	return ""


static func slots(state: MatchState, eid: int) -> int:
	return maxi(1, rules(state).slots + SpeciesTraits.empire_add(state, eid, "empire.research_slots"))


## Research points this tech costs the empire: pace, then tech.cost modifiers aimed at it.
static func cost(state: MatchState, eid: int, tech: String) -> int:
	var t := state.defs.get_def(StringName(tech)) as TechDef
	if t == null:
		return 0
	var per := 0
	for m: ModifierDef in SpeciesTraits.modifiers(state.defs, SpeciesTraits.source_of(state, eid), ModifierDef.Scope.EMPIRE):
		if String(m.key) == "tech.cost" and m.mode == ModifierDef.Mode.PERMILLE and StringName(tech) in (m.condition.get("tech", []) as Array):
			per += m.value
	return maxi(1, FixedMath.mul_permille(Pace.scale(t.cost, BuildRules.pace(state)), maxi(0, 1000 + per)))


## The techs being worked on now: the first researchable entries of the queue, up to the slot count.
static func active(state: MatchState, eid: int) -> Array[String]:
	var e := state.empire(eid)
	var out: Array[String] = []
	var n := slots(state, eid)
	for tech in e.research_queue:
		if out.size() >= n:
			break
		if not_ready(state, eid, tech) == "":
			out.append(tech)
	return out


## Monthly research for every empire (Sim month phase 1).
static func month_tick(state: MatchState) -> void:
	for eid: int in state.empires.ordered():
		_empire_month(state, eid)


static func _empire_month(state: MatchState, eid: int) -> void:
	var e := state.empire(eid)
	_prune(state, eid)
	var work := active(state, eid)
	var bank := int(e.treasury.get(RES, 0))
	if work.is_empty() or bank <= 0:
		return
	e.treasury[RES] = 0
	var points := FixedMath.mul_permille(bank, 1000 + SpeciesTraits.empire_permille(state, eid, "empire.research"))
	var share := points / work.size()
	var rest := points - share * work.size()
	var back := 0
	for i in work.size():
		var tech := work[i]
		var got := share + (rest if i == 0 else 0)
		var need := cost(state, eid, tech) * 1000 - int(e.research_progress.get(tech, 0))
		if got >= need:
			back += got - need
			complete(state, eid, tech)
		else:
			e.research_progress[tech] = int(e.research_progress.get(tech, 0)) + got
	if back > 0:
		e.treasury[RES] = int(e.treasury.get(RES, 0)) + back


## Grants a tech (research, reverse engineering, deals, starting techs): drops it and anything it locks
## from the queue, keeps partial progress of locked techs out of the save.
static func complete(state: MatchState, eid: int, tech: String) -> void:
	var e := state.empire(eid)
	if e == null or e.techs.has(tech):
		return
	e.techs[tech] = state.tick
	e.research_progress.erase(tech)
	e.research_queue.erase(tech)
	e.invalidate_source()
	_prune(state, eid)


## Drops queued techs the empire can no longer research (researched, or locked by an exclusive pick).
static func _prune(state: MatchState, eid: int) -> void:
	var e := state.empire(eid)
	var keep: Array[String] = []
	for tech in e.research_queue:
		if blocked(state, eid, tech) == "":
			keep.append(tech)
		else:
			e.research_progress.erase(tech)
	e.research_queue = keep


## Match start: species starting techs.
static func init_empire(state: MatchState, eid: int) -> void:
	var e := state.empire(eid)
	var sd := state.defs.get_def(StringName(e.species)) as SpeciesDef
	if sd == null:
		return
	for t in sd.starting_techs:
		e.techs[String(t)] = 0
	e.invalidate_source()


## Minimal AI choice until WP11: keep the queue at the slot count with the cheapest researchable techs
## (ties by ID). Every empire whose queue runs dry uses it; players can override with set_research.
static func auto_queue(state: MatchState, eid: int) -> void:
	var e := state.empire(eid)
	var n := slots(state, eid)
	if active(state, eid).size() >= n:
		return
	var options := []
	for def in state.defs.defs("tech"):
		var tech := String(def.id)
		if not e.research_queue.has(tech) and not_ready(state, eid, tech) == "":
			options.append([cost(state, eid, tech), tech])
	options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and String(a[1]) < String(b[1])))
	for o: Array in options:
		if active(state, eid).size() >= n:
			break
		e.research_queue.append(String(o[1]))
