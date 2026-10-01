class_name Supply
extends RefCounted
## Fuel supply (Sub-spec B6 freighter upkeep, B12 supply range). Monthly, units in ID order draw their hull's
## fuel upkeep from the nearest own stockpile in supply range: own colonies reach planet_supply_range lanes,
## stations their supply_range (outposts 1, depots 2/3/4). Nearest by lanes, then holder ID. A unit that
## can't get its full fuel is out of fuel and moves at half speed until a later draw succeeds (M2 rule; M3
## adds attrition for warships).

const FUEL := "core:resource/fuel"


static func month_tick(state: MatchState) -> void:
	var cover := {}  # owner -> {system: [[lanes, holder, stockpile], ...] nearest first, then holder ID}
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		var hull := state.defs.get_def(StringName(u.hull_id)) as HullDef if u.hull_id != "" else null
		var need: int = int(hull.upkeep.get(StringName(FUEL), 0)) * Stockpile.MILLI if hull else 0
		if need <= 0:
			continue
		if not cover.has(u.owner):
			cover[u.owner] = _coverage(state, u.owner)
		var src := StateIO.NONE
		for entry: Array in cover[u.owner].get(u.system_id, []):
			if (entry[2] as Stockpile).milli(FUEL) >= need:
				src = entry[1]
				break
		u.out_of_fuel = src == StateIO.NONE
		if not u.out_of_fuel:
			Holders.stockpile(state, src).take(FUEL, need)


## For every system some own holder supplies: those holders, nearest by lanes then by ID (same order as
## source_for; lanes are undirected, so a holder's range search covers exactly the systems that reach it).
static func _coverage(state: MatchState, owner: int) -> Dictionary:
	var out := {}
	var cache := {}
	for entry: Array in own_supply_points(state, owner):
		var hops := AutoLogistics.hops_within(state, entry[1], entry[2], cache)
		for sys_id: int in hops:
			if not out.has(sys_id):
				out[sys_id] = []
			out[sys_id].append([int(hops[sys_id]), entry[0], entry[3]])
	for sys_id: int in out:
		out[sys_id].sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return out


## [[holder, system, supply range, stockpile], ...] for every own holder.
static func own_supply_points(state: MatchState, owner: int) -> Array:
	var out := []
	for h in AutoLogistics._own_holders(state, owner):
		out.append([h, Holders.system(state, h), supply_range(state, h), Holders.stockpile(state, h)])
	return out


## The nearest own holder within supply range of a system that has `need` fuel, or NONE.
## points: optional precomputed own_supply_points for this owner.
static func source_for(state: MatchState, owner: int, system_id: int, need: int, cache: Dictionary, points: Array = []) -> int:
	if points.is_empty():
		points = own_supply_points(state, owner)
	var hops := AutoLogistics._hops_from(state, system_id, cache)  # exact lane counts, cached for the match
	var best := StateIO.NONE
	var best_hops := Sectors.FAR
	for entry: Array in points:
		var h: int = entry[0]
		var dist := int(hops.get(entry[1], Sectors.FAR))
		if dist > entry[2] or (entry[3] as Stockpile).milli(FUEL) < need:
			continue
		if dist < best_hops or (dist == best_hops and h < best):
			best = h
			best_hops = dist
	return best


static func supply_range(state: MatchState, holder: int) -> int:
	var s := state.station(holder)
	if s != null:
		return (state.defs.get_def(StringName(s.def_id)) as StationDef).supply_range
	return Economy.rules(state.defs).planet_supply_range
