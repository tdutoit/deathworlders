class_name SpeciesTraits
extends RefCounted
## Species trait modifiers (M4 WP1), summed per species and scope from SpeciesDef.traits. Content is frozen
## during a match, so the sums are cached per database (runtime only, like ShipStats._cache).

static var _cache := {}  # [db, species, scope] -> {key: [add, permille, condition-free?]}


## The species an owner plays ("" for pirates or nobody).
static func species_of(state: MatchState, owner: int) -> String:
	var e := state.empire(owner) if owner >= 0 else null
	return e.species if e != null else ""


## Trait modifiers of one scope: [ModifierDef, ...] in trait order.
static func modifiers(db: DefDatabase, species: String, scope: ModifierDef.Scope) -> Array:
	var key := [db, species, scope]
	if not _cache.has(key):
		var out := []
		var sd := db.get_def(StringName(species)) as SpeciesDef if species != "" else null
		if sd != null:
			for tid in sd.traits:
				var t := db.get_def(tid) as TraitDef
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
	for m: ModifierDef in modifiers(state.defs, species_of(state, owner), ModifierDef.Scope.EMPIRE):
		if String(m.key) == key:
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
