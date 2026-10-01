class_name Governor
extends RefCounted
## The built-in default governor (Sub-spec D2-D4; M2 has no leaders). Monthly, in colony ID order:
## updates colony stages, gives newly Developed planets a focus pair from their sector's directive, and builds
## the next item of the planet's template. Automated planets build; Assisted planets get a suggestion the
## player approves; Manual planets are left alone.

const LOGISTICS := "core:focus/logistics"


static func month_tick(state: MatchState) -> void:
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		update_stage(state, c)
		if c.autonomy == "manual":
			c.suggestion = ""
			continue
		if c.primary_focus == "" and c.stage in ["developed", "core"]:
			var pair := choose_focus(state, c)
			c.primary_focus = pair[0]
			c.secondary_focus = pair[1]
			Economy.assign_jobs(c, state.defs)
		var next := next_building(state, c)
		if c.autonomy == "assisted":
			c.suggestion = next
		elif next != "" and c.queue.is_empty():
			Builder.queue_building(state, c, next)


## D2 stages. Promotion needs pops, age and (for Core) stability and a nearby hub; a planet falls back a stage
## when it no longer meets its stage (pops or stability lost).
static func update_stage(state: MatchState, c: Colony) -> void:
	var r := Economy.rules(state.defs)
	var age := state.tick - c.founded_tick
	var pops := c.total_pops()
	var developed_ok := pops >= r.developed_pops and (age >= r.developed_years * Calendar.HOURS_PER_YEAR or c.stage in ["developed", "core"])
	if developed_ok and pops >= r.core_pops and c.stability >= r.core_stability and _hub_lanes(state, c) <= r.core_hub_lanes \
			and _reach(state, c) < r.reach_2:
		c.stage = "core"
	elif developed_ok:
		c.stage = "developed"
	else:
		c.stage = "colony"


static func _hub_lanes(state: MatchState, c: Colony) -> int:
	var sys := state.galaxy.planet(c.id).system_id
	var best := Sectors.FAR
	var cache := {}
	for sid: int in state.sectors:
		var sec: Sector = state.sectors.get_or(sid)
		if sec.owner == c.owner:
			best = mini(best, int(AutoLogistics._hops_from(state, Holders.system(state, sec.hub), cache).get(sys, Sectors.FAR)))
	return best


static func _reach(state: MatchState, c: Colony) -> int:
	return int(Sectors.reach_map(state, c.owner).get(state.galaxy.planet(c.id).system_id, Sectors.FAR))


## [primary, secondary] focus IDs from the sector directive (Balanced: best fit by deposits and habitability).
static func choose_focus(state: MatchState, c: Colony) -> Array[String]:
	var sec := Sectors.sector_of(state, c.owner, state.galaxy.planet(c.id).system_id)
	var d: DirectiveDef = state.defs.get_def(StringName(sec.directive if sec else "core:directive/balanced"))
	if not d.best_fit and not d.primary_foci.is_empty():
		for i in d.primary_foci.size():
			if _fits(state, c, String(d.primary_foci[i])):
				return [String(d.primary_foci[i]), String(d.secondary_foci[i])]
		return [String(d.primary_foci[0]), String(d.secondary_foci[0])]
	return best_fit(state, c)


## Placeholder best fit (M2): ore or rare-earth deposits -> Mining/Industrial; a comfortable world
## (habitability >= 800) -> Farming/Research; otherwise Research/Economy.
static func best_fit(state: MatchState, c: Colony) -> Array[String]:
	var planet := state.galaxy.planet(c.id)
	var raw := int(planet.deposits.get("core:resource/ore", 0)) + int(planet.deposits.get("core:resource/rare_earths", 0))
	if raw >= 2:
		return ["core:focus/mining", "core:focus/industrial"]
	var species: SpeciesDef = state.defs.get_def(StringName(state.empire(c.owner).species))
	if int(species.habitability.get(StringName(planet.planet_type), 0)) >= 800:
		return ["core:focus/farming", "core:focus/research"]
	return ["core:focus/research", "core:focus/economy"]


## A focus fits if at least one of its boosted jobs has a building this planet can hold.
static func _fits(state: MatchState, c: Colony, focus: String) -> bool:
	var f: FocusDef = state.defs.get_def(StringName(focus))
	if f.boosted_jobs.is_empty():
		return true
	for def in state.defs.defs("building"):
		var b: BuildingDef = def
		for job: StringName in b.jobs:
			if job in f.boosted_jobs and (b.requires_deposit == &"" or int(state.galaxy.planet(c.id).deposits.get(String(b.requires_deposit), 0)) > 0):
				return true
	return false


## The template the governor follows: the pinned one, the one for the focus pair, or the colony default.
static func template_for(state: MatchState, c: Colony) -> TemplateDef:
	if c.pinned_template != "":
		return state.defs.get_def(StringName(c.pinned_template))
	for def in state.defs.defs("template"):
		var t: TemplateDef = def
		if String(t.primary) == c.primary_focus and String(t.secondary) == c.secondary_focus:
			return t
	return null


## The first template entry not yet built or queued (counting repeats) that the planet can hold, or "".
static func next_building(state: MatchState, c: Colony) -> String:
	var t := template_for(state, c)
	if t == null:
		return ""
	var have := {}
	for b in c.buildings:
		have[b] = have.get(b, 0) + 1
	for q in c.queue:
		have[q.def_id] = have.get(q.def_id, 0) + 1
	var wanted := {}
	for entry in t.build_order:
		var b := String(entry)
		wanted[b] = wanted.get(b, 0) + 1
		if have.get(b, 0) >= wanted[b]:
			continue
		if BuildRules.check_building(state, c.owner, c.id, b) == "":
			return b
	return ""
