class_name Sectors
extends RefCounted
## Sectors and reach (Sub-spec D3, D9). Membership is recomputed monthly: each owned system joins the nearest
## hub whose range covers it (ties: lower sector ID). Reach = lanes to the nearest own sector hub.

const FAR := 1 << 20


## The capital colony, a Logistics Station with sector_range > 0, or a Logistics-focus colony.
static func check_hub(state: MatchState, eid: int, hub: int) -> String:
	var r := Economy.rules(state.defs)
	if Holders.owner(state, hub) != eid:
		return "hub %d is not yours" % hub
	for sid: int in state.sectors:
		if (state.sectors.get_or(sid) as Sector).hub == hub:
			return "already a sector hub"
	if count(state, eid) >= r.sector_cap:
		return "sector cap reached (%d)" % r.sector_cap
	var s := state.station(hub)
	if s != null:
		if not s.operational or (state.defs.get_def(StringName(s.def_id)) as StationDef).sector_range <= 0:
			return "a sector hub needs a Logistics Station T2 or better"
		return ""
	var c := state.colony(hub)
	if c != null and c.primary_focus != "core:focus/logistics" and hub != state.empire(eid).capital_planet:
		return "a planet hub needs Logistics as its Primary focus"
	return ""


static func count(state: MatchState, eid: int) -> int:
	var n := 0
	for sid: int in state.sectors:
		if (state.sectors.get_or(sid) as Sector).owner == eid:
			n += 1
	return n


static func create(state: MatchState, eid: int, hub: int) -> Sector:
	var sec := Sector.new()
	sec.id = state.alloc_id()
	sec.owner = eid
	sec.hub = hub
	state.sectors.put(sec.id, sec)
	update_membership(state)
	return sec


## Lanes a sector reaches from its hub.
static func range_of(state: MatchState, sec: Sector) -> int:
	var r := Economy.rules(state.defs)
	var s := state.station(sec.hub)
	if s != null:
		return (state.defs.get_def(StringName(s.def_id)) as StationDef).sector_range
	return r.core_sector_range if sec.hub == state.empire(sec.owner).capital_planet else r.colony_hub_range


static func update_membership(state: MatchState) -> void:
	var cache := {}
	for sid: int in state.sectors:
		(state.sectors.get_or(sid) as Sector).systems.clear()
	for sys_id: int in state.galaxy.systems:
		var owner := state.galaxy.system(sys_id).owner
		if owner == StateIO.NONE:
			continue
		var best: Sector = null
		var best_hops := FAR
		for sid: int in state.sectors:
			var sec: Sector = state.sectors.get_or(sid)
			if sec.owner != owner:
				continue
			var h := int(AutoLogistics._hops_from(state, Holders.system(state, sec.hub), cache).get(sys_id, FAR))
			if h <= range_of(state, sec) and h < best_hops:
				best = sec
				best_hops = h
		if best != null:
			best.systems.append(sys_id)


static func sector_of(state: MatchState, eid: int, system_id: int) -> Sector:
	for sid: int in state.sectors:
		var sec: Sector = state.sectors.get_or(sid)
		if sec.owner == eid and system_id in sec.systems:
			return sec
	return null


## system ID -> lanes to the nearest own sector hub (the capital system if the empire has no sectors).
static func reach_map(state: MatchState, eid: int) -> Dictionary:
	var cache := {}
	var out := {}
	var hubs: Array[int] = []
	for sid: int in state.sectors:
		var sec: Sector = state.sectors.get_or(sid)
		if sec.owner == eid:
			hubs.append(Holders.system(state, sec.hub))
	if hubs.is_empty():
		hubs.append(state.galaxy.planet(state.empire(eid).capital_planet).system_id)
	for hub_sys in hubs:
		var hops := AutoLogistics._hops_from(state, hub_sys, cache)
		for sys_id: int in hops:
			out[sys_id] = mini(int(out.get(sys_id, FAR)), int(hops[sys_id]))
	return out


## D9 reach band effects: [upkeep permille, stability].
static func reach_effects(r: EconomyRulesDef, reach: int) -> Array[int]:
	if reach >= r.reach_3:
		return [r.reach_upkeep_3, r.reach_stability_3]
	if reach >= r.reach_2:
		return [r.reach_upkeep_2, r.reach_stability_2]
	if reach >= r.reach_1:
		return [r.reach_upkeep_1, r.reach_stability_1]
	return [0, 0]
