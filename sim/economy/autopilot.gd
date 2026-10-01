class_name Autopilot
extends RefCounted
## The shared strategic automation for AI slots (Sub-spec D10, M2 subset). The operational layer (governor,
## auto-logistics) already runs for everyone; this adds a simple monthly expansion rule for empires whose slot
## controller is "ai":
##   1. settle idle colony ships on the best target; queue a colony ship when a target exists and none is busy;
##   2. claim the best nearby unclaimed system with an outpost when influence allows (one site at a time);
##   3. build mining stations on own belts, moons and gas giants (one site at a time);
##   4. add a freighter when berthed freighters are over 60% busy and a berth is free;
##   5. grow logistics: upgrade a hub, or add one at a colony, when no berth is free anywhere;
##   6. keep MIN_SHIPYARDS shipyards (B20: 2-3 by year 15);
##   7. steer the Core Sector directive: Research (Labs + Exchanges) while credits are short, else Industrial Core.
## Actions go through each Command's validate/apply but are not logged: replay re-derives them from state.

const BUSY_PERMILLE := 600  # add a freighter when more than 60% are working (B20 expects 20-40 by year 15)
const OUTPOST_RANGE := 2  # lanes from own territory
const MIN_SHIPYARDS := 2
const CORE_DIRECTIVE := "core:directive/industrial_core"
const CREDIT_DIRECTIVE := "core:directive/research"  # Research + Economy: Labs and Exchanges
const CREDIT_NET_LOW := 5000  # milli-credits a month
const CREDIT_CUSHION := 100000  # milli-credits kept before taking on new upkeep


static func is_ai(state: MatchState, eid: int) -> bool:
	var e := state.empire(eid)
	for p in state.settings.players:
		if int(p["slot"]) == e.player_slot:
			return p["controller"] == "ai"
	return false


static func month_tick(state: MatchState) -> void:
	for eid: int in state.empires:
		if is_ai(state, eid):
			_directive(state, eid)
			if not can_expand(state, eid):
				continue  # new colonies, stations and ships all add upkeep (B13)
			_colonise(state, eid)
			_outpost(state, eid)
			_mining(state, eid)
			_freighters(state, eid)
			_logistics(state, eid)
			_shipyards(state, eid)


## Expansion adds upkeep: only with a positive credit net, a cushion and no deficit.
static func can_expand(state: MatchState, eid: int) -> bool:
	var e := state.empire(eid)
	return e.deficit_months == 0 and e.credit_net > 0 and int(e.treasury.get("core:resource/credits", 0)) >= CREDIT_CUSHION


static func _do(state: MatchState, eid: int, type_id: StringName, payload: Dictionary) -> bool:
	var cmd := CommandRegistry.create(type_id, eid, payload)
	if not cmd.validate(state):
		return false
	cmd.apply(state)
	return true


# --- colonies ---

## Best colony target: settled-free, habitable planet in own systems or unclaimed systems near them
## (within OUTPOST_RANGE lanes of any own system, or of the ship's own system).
static func best_colony_target(state: MatchState, eid: int, from_system: int) -> int:
	var species: SpeciesDef = state.defs.get_def(StringName(state.empire(eid).species))
	var hops := _near_territory(state, eid, from_system)
	var best := StateIO.NONE
	var best_score := 0
	var candidates: Array[int] = []
	for sys_id: int in IdMap.sort_keys(hops.keys()):
		if int(hops[sys_id]) <= OUTPOST_RANGE:
			candidates.append_array(state.galaxy.system(sys_id).planet_ids)
	candidates.sort()
	for pid in candidates:
		var p := state.galaxy.planet(pid)
		var owner := state.galaxy.system(p.system_id).owner
		if state.colony(pid) != null or (owner != StateIO.NONE and owner != eid):
			continue
		var ptype: PlanetTypeDef = state.defs.get_def(StringName(p.planet_type))
		var hab := int(species.habitability.get(StringName(p.planet_type), 0))
		if ptype.orbital_only or hab < 500 or int(hops[p.system_id]) > OUTPOST_RANGE:
			continue
		var size: PlanetSizeDef = state.defs.get_def(PlanetSizeDef.id_for(p.size))
		var score := hab + size.housing * 20 + _deposit_score(p) - int(hops[p.system_id]) * 300 - (200 if owner == StateIO.NONE else 0)
		if score > best_score or (score == best_score and pid < best):
			best = pid
			best_score = score
	return best


## Lanes from the nearest own system (or `extra`) to every system within OUTPOST_RANGE.
static func _near_territory(state: MatchState, eid: int, extra: int) -> Dictionary:
	var scratch := state.scratch()
	var key := "near:%d:%d" % [eid, extra]
	if scratch.has(key):
		return scratch[key]
	var cache := {}
	var out := {}
	var sources: Array[int] = [extra]
	for sys_id: int in state.galaxy.systems:
		if state.galaxy.system(sys_id).owner == eid:
			sources.append(sys_id)
	for src in sources:
		var hops := AutoLogistics.hops_within(state, src, OUTPOST_RANGE, cache)
		for sys_id: int in hops:
			out[sys_id] = mini(int(out.get(sys_id, Sectors.FAR)), int(hops[sys_id]))
	scratch[key] = out
	return out


static func _deposit_score(p: Planet) -> int:
	var n := 0
	for res: String in p.deposits:
		n += int(p.deposits[res]) * 100
	return n


static func _colonise(state: MatchState, eid: int) -> void:
	var capital_sys := state.galaxy.planet(state.empire(eid).capital_planet).system_id
	var busy := false
	for uid: int in state.units.keys():
		var u: Unit = state.units.get_or(uid)
		if u.owner != eid or u.kind != "colony":
			continue
		if u.target_planet != StateIO.NONE:
			busy = true
			continue
		var target := best_colony_target(state, eid, u.system_id)
		if target != StateIO.NONE and _do(state, eid, CmdColonise.TYPE, {"unit": u.id, "planet": target}):
			busy = true
	if busy or best_colony_target(state, eid, capital_sys) == StateIO.NONE:
		return
	for sid: int in state.stations:
		var y: Station = state.stations.get_or(sid)
		if y.owner == eid and not y.ship_queue.is_empty() and y.ship_queue.any(func(q: Construction) -> bool: return q.def_id == "core:hull/colony_ship"):
			return  # one is being built
	for sid: int in state.stations:
		var y: Station = state.stations.get_or(sid)
		if y.owner == eid and _do(state, eid, CmdQueueShip.TYPE, {"station": y.id, "hull": "core:hull/colony_ship"}):
			return


# --- outposts and mining ---

static func _has_site(state: MatchState, eid: int, function: StringName) -> bool:
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if s.owner == eid and not s.operational and (state.defs.get_def(StringName(s.def_id)) as StationDef).function == function:
			return true
	return false


static func _outpost(state: MatchState, eid: int) -> void:
	if _has_site(state, eid, &"outpost") or Colonisation.can_pay_claim(state, eid) != "":
		return
	var cache := {}
	var best := StateIO.NONE
	var best_score := -1
	for sys_id: int in state.galaxy.systems:
		var sys := state.galaxy.system(sys_id)
		if sys.owner != StateIO.NONE:
			continue
		var near := false
		for lid in sys.lane_ids:
			if state.galaxy.system(state.galaxy.lane(lid).other_end(sys_id)).owner == eid:
				near = true
		if not near:
			continue
		var score := 0
		for pid in sys.planet_ids:
			score += _deposit_score(state.galaxy.planet(pid)) + 50
		if score > best_score:
			best = sys_id
			best_score = score
	if best != StateIO.NONE:
		_do(state, eid, CmdQueueStation.TYPE, {"planet": state.galaxy.system(best).planet_ids[0], "station": "core:station/outpost"})


static func _mining(state: MatchState, eid: int) -> void:
	if _has_site(state, eid, &"mining"):
		return
	var mining: Array = state.defs.defs("station").filter(func(d: StationDef) -> bool: return d.function == &"mining" and d.tier == 1)
	var used := {}  # planet -> stations orbiting it (one pass instead of one per check)
	for sid: int in state.stations:
		var pid := (state.stations.get_or(sid) as Station).planet_id
		used[pid] = int(used.get(pid, 0)) + 1
	for sys_id: int in state.galaxy.systems:
		if state.galaxy.system(sys_id).owner != eid:
			continue
		for pid in state.galaxy.system(sys_id).planet_ids:
			var p := state.galaxy.planet(pid)
			if int(used.get(pid, 0)) >= p.orbital_slots:
				continue
			for def: StationDef in mining:
				if not def.placement.is_empty() and not StringName(p.planet_type) in def.placement:
					continue
				if def.requires_deposit != &"" and int(p.deposits.get(String(def.requires_deposit), 0)) <= 0:
					continue
				if _do(state, eid, CmdQueueStation.TYPE, {"planet": pid, "station": String(def.id)}):
					return


# --- freighters ---

static func _freighters(state: MatchState, eid: int) -> void:
	var total := 0
	var busy := 0
	for uid: int in state.units:
		var u: Unit = state.units.get_or(uid)
		if u.owner == eid and u.kind == "freighter" and u.home != StateIO.NONE:
			total += 1
			if not Freight.plan(state, u).is_empty():
				busy += 1
	if total > 0 and busy * 1000 <= total * BUSY_PERMILLE:
		return
	var berth_checked := {}  # system -> a free berth exists (one berth search per system)
	for sid: int in state.stations:
		var y: Station = state.stations.get_or(sid)
		if y.owner != eid or not y.operational or (state.defs.get_def(StringName(y.def_id)) as StationDef).function != &"shipyard":
			continue
		if y.ship_queue.any(func(q: Construction) -> bool: return q.def_id == "core:hull/freighter_light"):
			continue
		if not berth_checked.has(y.system_id):
			berth_checked[y.system_id] = Shipyards.free_berth(state, eid, y.system_id) != StateIO.NONE
		if berth_checked[y.system_id] and _do(state, eid, CmdQueueShip.TYPE, {"station": y.id, "hull": "core:hull/freighter_light"}):
			return


# --- logistics hubs ---

## When no own hub has a free berth: upgrade a logistics station (lowest tier first, then ID), or put a
## Logistics Station T1 at the largest colony that has none. One site or upgrade at a time.
static func _logistics(state: MatchState, eid: int) -> void:
	var hubs: Array[Station] = []
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if s.owner != eid:
			continue
		var def: StationDef = state.defs.get_def(StringName(s.def_id))
		if def.function != &"logistics":
			continue
		if s.build != null:
			return  # one at a time
		hubs.append(s)
	for h in hubs:
		if Shipyards.berths_used(state, h.id) < Shipyards.berths(state, h.id):
			return  # a berth is free
	hubs.sort_custom(func(a: Station, b: Station) -> bool:
		var ta := (state.defs.get_def(StringName(a.def_id)) as StationDef).tier
		var tb := (state.defs.get_def(StringName(b.def_id)) as StationDef).tier
		return ta < tb if ta != tb else a.id < b.id)
	for h in hubs:
		if _do(state, eid, CmdUpgradeStation.TYPE, {"station": h.id}):
			return
	var best: Colony = null
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid and (best == null or c.total_pops() > best.total_pops()):
			var has_hub := BuildRules.stations_at(state, pid).any(func(s: Station) -> bool:
				return (state.defs.get_def(StringName(s.def_id)) as StationDef).function == &"logistics")
			if not has_hub:
				best = c
	if best != null:
		_do(state, eid, CmdQueueStation.TYPE, {"planet": best.id, "station": "core:station/logistics_t1"})


# --- shipyards ---

## Keeps MIN_SHIPYARDS shipyards: a Shipyard S at the most populous colony without one.
static func _shipyards(state: MatchState, eid: int) -> void:
	var count := 0
	var have := {}
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if s.owner == eid and (state.defs.get_def(StringName(s.def_id)) as StationDef).function == &"shipyard":
			count += 1
			have[s.planet_id] = true
	if count >= MIN_SHIPYARDS:
		return
	var best: Colony = null
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid and not have.has(pid) and (best == null or c.total_pops() > best.total_pops()):
			best = c
	if best != null:
		_do(state, eid, CmdQueueStation.TYPE, {"planet": best.id, "station": "core:station/shipyard_t1"})


# --- sector directive ---

static func _directive(state: MatchState, eid: int) -> void:
	var core := SectorLogistics.core_sector(state, eid)
	var want := CREDIT_DIRECTIVE if state.empire(eid).credit_net < CREDIT_NET_LOW else CORE_DIRECTIVE
	if core != null and core.directive != want:
		_do(state, eid, CmdSetDirective.TYPE, {"sector": core.id, "directive": want})
