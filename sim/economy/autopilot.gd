class_name Autopilot
extends RefCounted
## The shared strategic automation for AI slots (Sub-spec D10, M2 subset). The operational layer (governor,
## auto-logistics) already runs for everyone; this adds a simple monthly expansion rule for empires whose slot
## controller is "ai":
##   1. settle idle colony ships on the best target; queue a colony ship when a target exists and none is busy;
##   2. claim the best nearby unclaimed system with an outpost when influence allows (one site at a time);
##   3. build mining stations on own belts, moons and gas giants (one site at a time);
##   4. add a freighter when berthed freighters are over 95% busy and a berth is free.
## Actions go through each Command's validate/apply but are not logged: replay re-derives them from state.

const BUSY_PERMILLE := 950
const OUTPOST_RANGE := 2  # lanes from own territory


static func is_ai(state: MatchState, eid: int) -> bool:
	var e := state.empire(eid)
	for p in state.settings.players:
		if int(p["slot"]) == e.player_slot:
			return p["controller"] == "ai"
	return false


static func month_tick(state: MatchState) -> void:
	for eid: int in state.empires:
		if is_ai(state, eid):
			_colonise(state, eid)
			_outpost(state, eid)
			_mining(state, eid)
			_freighters(state, eid)


static func _do(state: MatchState, eid: int, type_id: StringName, payload: Dictionary) -> bool:
	var cmd := CommandRegistry.create(type_id, eid, payload)
	if not cmd.validate(state):
		return false
	cmd.apply(state)
	return true


# --- colonies ---

## Best colony target: settled-free, habitable planet in own systems or unclaimed systems near them.
static func best_colony_target(state: MatchState, eid: int, from_system: int) -> int:
	var species: SpeciesDef = state.defs.get_def(StringName(state.empire(eid).species))
	var hops := AutoLogistics.hops_within(state, from_system, OUTPOST_RANGE, {})
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
