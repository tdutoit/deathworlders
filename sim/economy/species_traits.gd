class_name SpeciesTraits
extends RefCounted
## An empire's own modifiers: its species traits (M4 WP1, SpeciesDef.traits) and its researched techs (M5 WP2),
## per scope. A modifier source is "species" or "species|tech,tech,..." (Empire.source()); content is frozen
## during a match, so the lists are cached per database and source (runtime only, like ShipStats._cache).

static var _cache := {}  # [db, source, scope] -> [ModifierDef, ...]


## The modifier source of an owner: species plus researched techs ("" for pirates or nobody).
static func source_of(state: MatchState, owner: int) -> String:
	var e := state.empire(owner) if owner >= 0 else null
	return e.source() if e != null else ""


## Trait then tech modifiers of one scope: [ModifierDef, ...] in trait order, then tech ID order.
static func modifiers(db: DefDatabase, source: String, scope: ModifierDef.Scope) -> Array:
	var key := [db, source, scope]
	if not _cache.has(key):
		if _cache.size() > 4096:
			_cache.clear()  # old sources (before a tech) are never asked for again
		var out := []
		var species := source.get_slice("|", 0)
		var sd := db.get_def(StringName(species)) as SpeciesDef if species != "" else null
		if sd != null:
			for tid in sd.traits:
				var t := db.get_def(tid) as TraitDef
				if t == null:
					continue
				for m in t.modifiers:
					if m.scope == scope:
						out.append(m)
		var techs := source.get_slice("|", 1) if source.contains("|") else ""
		if techs != "":
			for tid in techs.split(","):
				var t := db.get_def(StringName(tid)) as TechDef
				if t == null:
					continue
				for m in t.modifiers:
					if m.scope == scope:
						out.append(m)
		_cache[key] = out
	return _cache[key]


## [add, permille] of an EMPIRE-scope key for the owner's species.
static func empire(state: MatchState, owner: int, key: String) -> Array[int]:
	var out: Array[int] = [0, 0]
	for m: ModifierDef in modifiers(state.defs, source_of(state, owner), ModifierDef.Scope.EMPIRE):
		if String(m.key) == key and m.condition.is_empty():  # conditioned keys are read by their own system
			out[0 if m.mode == ModifierDef.Mode.ADD else 1] += m.value
	return out


static func empire_add(state: MatchState, owner: int, key: String) -> int:
	return empire(state, owner, key)[0]


static func empire_permille(state: MatchState, owner: int, key: String) -> int:
	return empire(state, owner, key)[1]


## The species most of a colony's pops belong to (ties: lowest ID), or "".
static func dominant(c: Colony) -> String:
	var best := ""
	var best_n := 0
	for sp: String in IdMap.sort_keys(c.pops.keys()):
		if int(c.pops[sp]) > best_n:
			best = sp
			best_n = int(c.pops[sp])
	return best
