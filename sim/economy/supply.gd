class_name Supply
extends RefCounted
## Fuel supply (Sub-spec B6 freighter upkeep, B12 supply range). Monthly, units in ID order draw their hull's
## fuel upkeep from the nearest own stockpile in supply range: own colonies reach planet_supply_range lanes,
## stations their supply_range (outposts 1, depots 2/3/4). Nearest by lanes, then holder ID. A unit that
## can't get its full fuel is out of fuel and moves at half speed until a later draw succeeds (M2 rule; M3
## adds attrition for warships).

const FUEL := "core:resource/fuel"


static func month_tick(state: MatchState) -> void:
	var cache := {}
	for uid: int in state.units:
		var u: Unit = state.units.get_or(uid)
		var hull := state.defs.get_def(StringName(u.hull_id)) as HullDef if u.hull_id != "" else null
		var need: int = int(hull.upkeep.get(StringName(FUEL), 0)) * Stockpile.MILLI if hull else 0
		if need <= 0:
			continue
		var src := source_for(state, u.owner, u.system_id, need, cache)
		u.out_of_fuel = src == StateIO.NONE
		if not u.out_of_fuel:
			Holders.stockpile(state, src).take(FUEL, need)


## The nearest own holder within supply range of a system that has `need` fuel, or NONE.
static func source_for(state: MatchState, owner: int, system_id: int, need: int, cache: Dictionary) -> int:
	var hops := AutoLogistics._hops_from(state, system_id, cache)
	var best := StateIO.NONE
	var best_hops := Sectors.FAR
	for h in AutoLogistics._own_holders(state, owner):
		var reach := supply_range(state, h)
		var dist := int(hops.get(Holders.system(state, h), Sectors.FAR))
		if dist > reach or Holders.stockpile(state, h).milli(FUEL) < need:
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
