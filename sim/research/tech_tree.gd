class_name TechTree
extends RefCounted
## Static queries over the tech Defs (M5 WP1): what a tech unlocks and the B14 tier rule. Pure functions of
## the frozen DefDatabase; empire research state comes in WP2.

const GATED_CATEGORIES: Array[String] = ["hull", "component", "building", "station", "treaty"]


## Every Def whose requires_tech lists `tech_id`, sorted by ID.
static func unlocks(db: DefDatabase, tech_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for category in GATED_CATEGORIES:
		for def in db.defs(category):
			if tech_id in (def.get("requires_tech") as Array):
				out.append(def.id)
	out.sort()
	return out


## Techs of `branch` and `tier` one empire can research at most: those open to everyone, plus those limited
## to one of `species` (empty = only the general techs), counting one per exclusive pair.
static func reachable_in_tier(db: DefDatabase, branch: StringName, tier: int, species: Array[StringName]) -> int:
	var open: Array[StringName] = []
	for id: String in db.all_ids():  # all_ids, not defs(): content validation runs before the freeze
		var t := db.get_def(StringName(id)) as TechDef
		if t != null and t.branch == branch and t.tier == tier and _open_to(t, species):
			open.append(t.id)
	var count := open.size()
	for tid in open:
		for x in (db.get_def(tid) as TechDef).exclusive_with:
			if x in open and String(tid) < String(x):
				count -= 1
	return count


static func _open_to(t: TechDef, species: Array[StringName]) -> bool:
	if t.species_only.is_empty():
		return true
	for s in species:
		if s in t.species_only:
			return true
	return false
