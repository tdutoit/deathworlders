class_name BroodSurgeMechanic
extends SignatureMechanic
## Brood Surge (Krothi; main spec 10.1; M4 WP9, owner placeholders): a colony with surge_min_pops pops may
## surge: surge_pops pops become a Krothi corvette (the standard design) at the colony's system after
## surge_days, with no alloys and surge_component_permille of its components; once per colony per
## surge_cooldown_months. The enormous food burden is the Ravenous trait (WP1).
## State: {"cooldown": {"planet ID": tick of last surge}, "pending": [[system, ready tick], ...]}.

const DESIGN := "core:design/krothi_corvette_standard"


func init_state(_state: MatchState, e: Empire) -> void:
	e.mechanic = {"cooldown": {}, "pending": []}


## "" if this colony can surge now, else why.
static func check(state: MatchState, eid: int, planet_id: int) -> String:
	var e := state.empire(eid)
	if not SignatureMechanics.of(state, e) is BroodSurgeMechanic:
		return "only the Krothi Brood can surge"
	var c := state.colony(planet_id)
	var r := SignatureMechanics.rules(state)
	if c == null or c.owner != eid:
		return "not your colony"
	if c.total_pops() < r.surge_min_pops:
		return "needs %d pops" % r.surge_min_pops
	var last := int((e.mechanic.get("cooldown", {}) as Dictionary).get(str(planet_id), -1))
	if last >= 0 and state.tick - last < r.surge_cooldown_months * Calendar.HOURS_PER_MONTH:
		return "this colony surged too recently"
	if c.stockpile.milli("core:resource/components") < _components(state) * Stockpile.MILLI:
		return "needs %d components" % _components(state)
	return ""


static func _components(state: MatchState) -> int:
	var d := state.defs.get_def(StringName(DESIGN)) as DesignDef
	var cost := ShipStats.cost(state.defs, String(d.hull), Array(d.components).map(func(x: StringName) -> String: return String(x)))
	return FixedMath.mul_permille(int(cost.get("core:resource/components", 0)), SignatureMechanics.rules(state).surge_component_permille)


static func surge(state: MatchState, eid: int, planet_id: int) -> void:
	var e := state.empire(eid)
	var c := state.colony(planet_id)
	var r := SignatureMechanics.rules(state)
	c.stockpile.take("core:resource/components", _components(state) * Stockpile.MILLI)
	for i in r.surge_pops:
		Economy._remove_pop(c)
	Economy.assign_jobs(c, state.defs)
	var cd: Dictionary = e.mechanic.get("cooldown", {})
	cd[str(planet_id)] = state.tick
	e.mechanic["cooldown"] = cd
	var pending: Array = e.mechanic.get("pending", [])
	pending.append([state.galaxy.planet(planet_id).system_id, state.tick + r.surge_days * Calendar.HOURS_PER_DAY])
	e.mechanic["pending"] = pending


func day_tick(state: MatchState, e: Empire) -> void:
	var pending: Array = e.mechanic.get("pending", [])
	if pending.is_empty():
		return
	var keep := []
	var d := state.defs.get_def(StringName(DESIGN)) as DesignDef
	for p: Array in pending:
		if state.tick < int(p[1]):
			keep.append(p)
			continue
		var u := Shipyards.spawn(state, e.id, String(d.hull), int(p[0]))
		u.components.assign(Array(d.components).map(func(x: StringName) -> String: return String(x)))
		Fleets.commission(state, u)
	e.mechanic["pending"] = keep


func meter(state: MatchState, e: Empire) -> Dictionary:
	var ready := 0
	for pid: int in state.colonies.ordered():
		if (state.colonies.get_or(pid) as Colony).owner == e.id and check(state, e.id, pid) == "":
			ready += 1
	return {"BROOD_SURGE_READY": ready}
