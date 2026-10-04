class_name Fog
extends RefCounted
## Fog of war (Sub-spec D12; M5 WP5). Each empire's Knowledge is recomputed once a day in its own hour
## (with its auto-logistics): sensor coverage from its sources, then the detection contest for foreign units in
## covered systems, then explored systems and ghosts. The UI and the AI read it through level(), sees() and
## owner_seen(); with fog Off every query answers as full visibility.
## Sources: own systems (owned planet or outpost) at owned_strength; listening posts (sensor_range lanes,
## sensor_strength + empire.sensor_strength); colonies with planet.sensor_range (Deep Space Array) at
## owned_strength over that many lanes; own units at unit_strength (scouts scout_strength, +scout_range lanes);
## allies' sources too (alliance: shared vision, E4).

enum { UNKNOWN, EXPLORED, COVERED }

const OFF := "off"
const HARDCORE := "hardcore"

static var _sig_cache := {}  # [db, hull, components, source] -> signature before innate stealth (runtime only)


static func rules(state: MatchState) -> FogRulesDef:
	return state.defs.get_def(FogRulesDef.ID) as FogRulesDef


static func enabled(state: MatchState) -> bool:
	return state.settings.fog != OFF and state.defs != null and rules(state) != null


static func knowledge(state: MatchState, eid: int) -> Knowledge:
	var k: Knowledge = state.knowledge.get_or(eid)
	if k == null:
		k = Knowledge.new()
		k.id = eid
		state.knowledge.put(eid, k)
	return k


# --- queries ---

static func level(state: MatchState, eid: int, system_id: int) -> int:
	if not enabled(state) or state.empire(eid) == null or state.empire(eid).full_vision:
		return COVERED
	var k: Knowledge = state.knowledge.get_or(eid)
	if k == null:
		return UNKNOWN
	if k.covered.has(system_id):
		return COVERED
	return EXPLORED if k.explored.has(system_id) else UNKNOWN


## Whether the empire sees this unit now (its own units, and every unit with fog Off, always).
static func sees(state: MatchState, eid: int, unit_id: int) -> bool:
	var u: Unit = state.units.get_or(unit_id)
	if u == null:
		return false
	if not enabled(state) or u.owner == eid or (state.empire(eid) != null and state.empire(eid).full_vision):
		return true
	var k: Knowledge = state.knowledge.get_or(eid)
	return k != null and k.visible.has(unit_id)


## A system's owner as the empire last saw it (live while covered; NONE when unexplored).
static func owner_seen(state: MatchState, eid: int, system_id: int) -> int:
	if level(state, eid, system_id) == COVERED:
		return state.galaxy.system(system_id).owner
	var k: Knowledge = state.knowledge.get_or(eid)
	return int(k.explored[system_id][0]) if k != null and k.explored.has(system_id) else StateIO.NONE


# --- daily update ---

static func init_all(state: MatchState) -> void:
	if not enabled(state):
		return
	for eid: int in state.empires.ordered():
		empire_day(state, eid)


static func empire_day(state: MatchState, eid: int) -> void:
	if not enabled(state):
		return
	var r := rules(state)
	var k := knowledge(state, eid)
	var cov := coverage(state, eid, r)
	for other: int in state.empires.ordered():
		if other != eid and Treaties.has_effect(state, eid, other, "alliance"):
			var shared := coverage(state, other, r)
			for sid: int in shared:
				cov[sid] = maxi(int(cov.get(sid, 0)), int(shared[sid]))
	k.covered = cov
	for sid: int in cov:
		k.explored[sid] = [state.galaxy.system(sid).owner, state.tick]
	var was := k.visible
	k.visible = {}
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner == eid or not cov.has(u.system_id):
			continue
		if int(cov[u.system_id]) + signature(state, u, r) >= r.threshold:
			k.visible[uid] = true
	_ghosts(state, k, was, r)
	Intel.empire_day(state, eid, r)  # WP6


static func _ghosts(state: MatchState, k: Knowledge, was: Dictionary, r: FogRulesDef) -> void:
	for uid: int in k.visible:
		k.ghosts.erase(uid)
	if state.settings.fog != HARDCORE:
		for uid: int in IdMap.sort_keys(was.keys()):
			if k.visible.has(uid):
				continue
			var u: Unit = state.units.get_or(uid)
			if u == null:
				continue  # destroyed or gone: nothing to remember
			var h := state.defs.get_def(StringName(u.hull_id)) as HullDef
			k.ghosts[uid] = {"system": u.system_id, "owner": u.owner, "kind": u.kind,
				"size": String(h.size) if h != null else "S", "tick": state.tick}
	var expire := state.tick - r.ghost_days * Calendar.HOURS_PER_DAY
	var order := []
	for uid: int in IdMap.sort_keys(k.ghosts.keys()):
		if int(k.ghosts[uid]["tick"]) < expire:
			k.ghosts.erase(uid)
		else:
			order.append([int(k.ghosts[uid]["tick"]), uid])
	if order.size() > r.ghost_cap:
		order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		for i in order.size() - r.ghost_cap:
			k.ghosts.erase(order[i][1])


## System ID -> best sensor strength from this empire's own sources.
static func coverage(state: MatchState, eid: int, r: FogRulesDef) -> Dictionary:
	var cov := {}
	var g := state.galaxy
	for sid: int in g.systems.ordered():
		if g.system(sid).owner == eid:
			_cover(cov, sid, r.owned_strength)
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		if c.owner != eid:
			continue
		var sys := g.planet(pid).system_id
		_cover(cov, sys, r.owned_strength)
		var extra := PlanetMods.of(state, c).add("planet.sensor_range")
		if extra > 0:
			_spread(state, cov, sys, extra, r.owned_strength)
	var bonus := SpeciesTraits.empire_add(state, eid, "empire.sensor_strength")
	for stid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(stid)
		if s.owner != eid or not s.operational:
			continue
		var def := state.defs.get_def(StringName(s.def_id)) as StationDef
		if def.sensor_range > 0 or def.sensor_strength > 0:
			_spread(state, cov, s.system_id, def.sensor_range, def.sensor_strength + bonus)
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner != eid:
			continue
		if u.kind == "scout":
			_spread(state, cov, u.system_id, r.scout_range, r.scout_strength)
		else:
			_cover(cov, u.system_id, r.unit_strength)
	Espionage.add_coverage(state, eid, cov)  # WP9: gather_intel agents
	return cov


static func _cover(cov: Dictionary, sid: int, strength: int) -> void:
	if strength > int(cov.get(sid, -1)):
		cov[sid] = strength


## Covers every system within `lanes` lane hops of `from` (breadth-first, lane ID order).
static func _spread(state: MatchState, cov: Dictionary, from: int, lanes: int, strength: int) -> void:
	var seen := {from: true}
	var frontier: Array[int] = [from]
	_cover(cov, from, strength)
	for depth in lanes:
		var next: Array[int] = []
		for sid in frontier:
			for lid in state.galaxy.system(sid).lane_ids:
				var o := state.galaxy.lane(lid).other_end(sid)
				if not seen.has(o):
					seen[o] = true
					next.append(o)
					_cover(cov, o, strength)
		frontier = next


## A unit's signature minus its stealth (D12): hull size (freighters freighter_signature), ship.signature from
## its components and its owner's techs and traits, freighter.signature for freighters, innate stealth.
static func signature(state: MatchState, u: Unit, r: FogRulesDef) -> int:
	var source := SpeciesTraits.source_of(state, u.owner)
	var key := [state.defs, u.hull_id, u.components, source]
	var base: Variant = _sig_cache.get(key)
	if base == null:
		if _sig_cache.size() > 8192:
			_sig_cache.clear()
		var h := state.defs.get_def(StringName(u.hull_id)) as HullDef
		var sig := r.freighter_signature if u.kind == "freighter" else int(r.signature_by_size.get(h.size if h != null else &"S", 20))
		for cid in u.components:
			var c := state.defs.get_def(StringName(cid)) as ComponentDef if cid != "" else null
			if c != null:
				for m in c.modifiers:
					if m.key == &"ship.signature" and m.mode == ModifierDef.Mode.ADD:
						sig += m.value
		for m: ModifierDef in SpeciesTraits.modifiers(state.defs, source, ModifierDef.Scope.SHIP):
			if m.key == &"ship.signature" and m.mode == ModifierDef.Mode.ADD and m.condition.is_empty():
				sig += m.value
		if u.kind == "freighter":
			sig += SpeciesTraits.empire_add(state, u.owner, "freighter.signature")
		base = sig
		_sig_cache[key] = sig
	var stealth := r.pirate_stealth if u.owner < 0 else int(r.species_stealth.get(StringName(source.get_slice("|", 0)), 0))
	return maxi(0, int(base) - stealth)
