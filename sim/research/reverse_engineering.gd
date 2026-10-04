class_name ReverseEngineering
extends RefCounted
## Reverse engineering (main spec 8.3, Sub-spec B14; M5 WP8; owner rules 2026-10-04). Battle salvage gives
## tech fragments of the losing side's species (Empire.fragments). With the Reverse Engineering tech
## (empire.reverse_engineering), `reverse_fragments` (+ empire.reverse_fragments: humans 70) buy one tech any
## empire of that species has researched and the buyer lacks: it joins the queue at `reverse_cost_permille`
## (+ empire.reverse_cost) of its cost and skips the tier rule, prereqs and species locks (not exclusive
## picks). At most `reverse_unlocks` (+ empire.reverse_extra_unlocks) per species. Each unlock gives that
## species' empires in contact an opinion event: admired (xenophilia >= admire_xenophilia) or stolen.
## Hybrid Technology (empire.hybrid_variants) opens the human-adapted parts (ComponentDef.hybrid_of) of every
## species the empire has reverse-engineered from.


static func needed(state: MatchState, eid: int) -> int:
	return maxi(1, Research.rules(state).reverse_fragments + SpeciesTraits.empire_add(state, eid, "empire.reverse_fragments"))


static func cap(state: MatchState, eid: int) -> int:
	return Research.rules(state).reverse_unlocks + SpeciesTraits.empire_add(state, eid, "empire.reverse_extra_unlocks")


static func used(state: MatchState, eid: int, species: String) -> int:
	var n := 0
	var e := state.empire(eid)
	for tech: String in e.reversed:
		if String(e.reversed[tech]) == species:
			n += 1
	return n


## Techs empires of `species` have researched that `eid` lacks and may still take (sorted by ID).
static func options(state: MatchState, eid: int, species: String) -> Array[String]:
	var e := state.empire(eid)
	var seen := {}
	for other: int in state.empires.ordered():
		var o := state.empire(other)
		if other == eid or o.species != species:
			continue
		for tech: String in o.techs:
			if not e.techs.has(tech) and not e.reversed.has(tech) and not _locked(state, e, tech):
				seen[tech] = true
	var out: Array[String] = []
	for tech: String in IdMap.sort_keys(seen.keys()):
		out.append(tech)
	return out


static func _locked(state: MatchState, e: Empire, tech: String) -> bool:
	var t := state.defs.get_def(StringName(tech)) as TechDef
	if t == null:
		return true
	for x in t.exclusive_with:
		if e.techs.has(String(x)):
			return true
	return false


## Why `eid` can't reverse-engineer `tech` from `species` now ("" = it can).
static func check(state: MatchState, eid: int, species: String, tech: String) -> String:
	var e := state.empire(eid)
	if e == null:
		return "no empire"
	if SpeciesTraits.empire_add(state, eid, "empire.reverse_engineering") <= 0:
		return "needs the Reverse Engineering tech"
	if species == e.species:
		return "your own species"
	if int(e.fragments.get(species, 0)) < needed(state, eid):
		return "needs %d %s fragments" % [needed(state, eid), species]
	if used(state, eid, species) >= cap(state, eid):
		return "no more unlocks from %s" % species
	if not tech in options(state, eid, species):
		return "%s has no %s to copy" % [species, tech]
	return ""


static func apply(state: MatchState, eid: int, species: String, tech: String) -> void:
	var e := state.empire(eid)
	e.fragments[species] = int(e.fragments[species]) - needed(state, eid)
	e.reversed[tech] = species
	if not e.research_queue.has(tech):
		e.research_queue.append(tech)
	e.invalidate_source()  # hybrid parts may open
	var r := Research.rules(state)
	for other: int in state.empires.ordered():
		var o := state.empire(other)
		if other == eid or o.species != species or not Relations.has_contact(state, other, eid):
			continue
		if Treaties.personality(state, other, "xenophilia") >= r.admire_xenophilia:
			Relations.add_event(state, other, eid, "tech_admired", r.admire_opinion)
		else:
			Relations.add_event(state, other, eid, "tech_stolen", r.stolen_opinion)


## Salvage fragments of a species to an empire.
static func add_fragments(state: MatchState, eid: int, species: String, amount: int) -> void:
	var e := state.empire(eid)
	if e == null or species == "" or amount <= 0:
		return
	e.fragments[species] = int(e.fragments.get(species, 0)) + amount
	e.tech_fragments += amount


## "" if the empire may fit this component as far as hybrid rules go, else the reason.
static func hybrid_missing(state: MatchState, eid: int, c: ComponentDef) -> String:
	if c.hybrid_of == &"":
		return ""
	if SpeciesTraits.empire_add(state, eid, "empire.hybrid_variants") <= 0:
		return "needs Hybrid Technology"
	if used(state, eid, String(c.hybrid_of)) <= 0:
		return "needs a reverse-engineered %s tech" % c.hybrid_of
	return ""


## AI: spend fragments on the cheapest copyable tech of each species it can (WP11 refines).
static func auto(state: MatchState, eid: int) -> void:
	var e := state.empire(eid)
	for species: String in IdMap.sort_keys(e.fragments.keys()):
		var best := ""
		var best_cost := 0
		for tech in options(state, eid, species):
			var c := (state.defs.get_def(StringName(tech)) as TechDef).cost
			if best == "" or c < best_cost:
				best = tech
				best_cost = c
		if best != "" and check(state, eid, species, best) == "":
			apply(state, eid, species, best)
