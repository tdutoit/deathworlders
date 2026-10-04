class_name Autopilot
extends RefCounted
## The shared strategic automation for AI slots (Sub-spec D10, M2 subset). The operational layer (governor,
## auto-logistics) already runs for everyone; this adds a simple monthly expansion rule for empires whose slot
## controller is "ai":
##   1. settle idle colony ships on the best target; queue a colony ship when a target exists and none is busy;
##   2. claim the best nearby unclaimed system with an outpost when influence allows (one site at a time);
##   3. build mining stations on own belts, moons and gas giants (one site at a time; deposit miners first);
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
const CREDIT_LOW := 300000  # milli-credits: below this (with a low net) the Core Sector runs on Research
const SMALL_COLONY_POPS := 3
const MAX_SMALL_COLONIES := 2  # no new colony ship while this many colonies are still under SMALL_COLONY_POPS
const ORE_SITE_SCORE := 300  # outpost targeting: a body that takes an ore mining station
const HAB_GOOD := 500  # colony targets: habitability permille the AI prefers
const HAB_FALLBACK := 300  # ... and the least it accepts when nothing better is in reach
const MAX_COLONIES := 10  # the AI stops sending colony ships here (B20 mid-game empire: 6-10 colonies)
const CREDIT_CUSHION := 100000  # milli-credits kept before taking on new upkeep
const RARE_EARTHS := "core:resource/rare_earths"
const RE_MINE := "core:building/re_mine"
const RARE_EARTHS_LOW := 100  # below this stock (whole units) the AI builds a rare earths mine (M4 WP14)


static func is_ai(state: MatchState, eid: int) -> bool:
	var e := state.empire(eid)
	for p in state.settings.players:
		if int(p["slot"]) == e.player_slot:
			return p["controller"] == "ai"
	return false


static func month_tick(state: MatchState) -> void:
	for eid: int in state.empires.ordered():
		empire_month(state, eid)


## One AI empire's monthly turn (the sim gives each empire its own hour, Sim._month_phase).
static func empire_month(state: MatchState, eid: int) -> void:
	if not is_ai(state, eid):
		return
	_directive(state, eid)
	MilitaryAutopilot.month_tick(state, eid, can_expand(state, eid))  # M3 WP10
	if not can_expand(state, eid):
		return  # new colonies, stations and ships all add upkeep (B13)
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
	SignatureMechanics.command_applied(state, cmd)
	return true


# --- colonies ---

## Best colony target: settled-free, habitable planet in own systems or unclaimed systems near them
## (within OUTPOST_RANGE lanes of any own system, or of the ship's own system).
static func best_colony_target(state: MatchState, eid: int, from_system: int) -> int:
	var species: SpeciesDef = state.defs.get_def(StringName(state.empire(eid).species))
	var hops := _near_territory(state, eid, from_system)
	var best := [StateIO.NONE, StateIO.NONE]  # [good habitability, fallback], each with its score below
	var best_score := [0, 0]
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
		if ptype.orbital_only or hab < HAB_FALLBACK or int(hops[p.system_id]) > OUTPOST_RANGE:
			continue
		var tier := 0 if hab >= HAB_GOOD else 1
		if not _served(state, eid, p.system_id):
			continue  # no own hub's freighters reach it: its Farm would never arrive
		if state.pirate_bases.has(p.system_id) or Pirates.raided_systems(state, eid).has(p.system_id):
			continue  # raiders there (a base never leaves without warships)
		var size: PlanetSizeDef = state.defs.get_def(PlanetSizeDef.id_for(p.size))
		var score := hab + size.housing * 20 + _deposit_score(p) - int(hops[p.system_id]) * 300 - (200 if owner == StateIO.NONE else 0)
		if score > best_score[tier] or (score == best_score[tier] and pid < best[tier]):
			best[tier] = pid
			best_score[tier] = score
	# Poorer worlds only when nothing good is in reach (species with few liked planet types, e.g. Vesskar).
	return best[0] if best[0] != StateIO.NONE else best[1]


## True when some own hub with berths has the system within its freight range (B8).
static func _served(state: MatchState, eid: int, system_id: int) -> bool:
	return served_systems(state, eid).has(system_id)


## {system: true} within freight range of one of the empire's hubs with berths (once per tick).
static func served_systems(state: MatchState, eid: int) -> Dictionary:
	var scratch := state.scratch()
	var key := "served:%d" % eid
	if not scratch.has(key):
		var out := {}
		var cache := {}
		for h in AutoLogistics._own_holders(state, eid):
			if Shipyards.berths(state, h) > 0:
				for sys_id: int in AutoLogistics.hops_within(state, Holders.system(state, h), AutoLogistics.hub_range(state, h), cache):
					out[sys_id] = true
		scratch[key] = out
	return scratch[key]


## Lanes from the nearest own system (or `extra`) to every system within OUTPOST_RANGE.
static func _near_territory(state: MatchState, eid: int, extra: int) -> Dictionary:
	var scratch := state.scratch()
	var key := "near:%d:%d" % [eid, extra]
	if scratch.has(key):
		return scratch[key]
	var cache := {}
	var out := {}
	var sources: Array[int] = [extra]
	for sys_id: int in state.galaxy.systems.ordered():
		if state.galaxy.system(sys_id).owner == eid:
			sources.append(sys_id)
	for src in sources:
		var hops := AutoLogistics.hops_within(state, src, OUTPOST_RANGE, cache)
		for sys_id: int in hops:
			out[sys_id] = mini(int(out.get(sys_id, Sectors.FAR)), int(hops[sys_id]))
	scratch[key] = out
	return out


## A body a mining station producing ore can orbit (placement only; slots are checked when building).
static func _ore_site(state: MatchState, p: Planet) -> bool:
	for def in state.defs.defs("station"):
		var d: StationDef = def
		if d.function == &"mining" and d.outputs.has(&"core:resource/ore") and StringName(p.planet_type) in d.placement:
			return true
	return false


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
	if busy:
		return
	# Cheap gates first; the target search (the costly part) only when a ship would really be queued.
	var small := 0
	var owned := 0
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid:
			owned += 1
			if c.total_pops() < SMALL_COLONY_POPS:
				small += 1
	if owned >= MAX_COLONIES:
		return
	if small >= MAX_SMALL_COLONIES:
		return  # let the young colonies grow first (each costs upkeep and freight until its Farm)
	for sid: int in state.stations.ordered():
		var y: Station = state.stations.get_or(sid)
		if y.owner == eid and not y.ship_queue.is_empty() and y.ship_queue.any(func(q: Construction) -> bool: return q.def_id == "core:hull/colony_ship"):
			return  # one is being built
	if best_colony_target(state, eid, capital_sys) == StateIO.NONE:
		return
	var yards: Array[Station] = []  # shortest queue first (M3: warships may be building), then ID
	for sid: int in state.stations.ordered():
		var y: Station = state.stations.get_or(sid)
		if y.owner == eid:
			yards.append(y)
	yards.sort_custom(func(a: Station, b: Station) -> bool:
		return a.ship_queue.size() < b.ship_queue.size() or (a.ship_queue.size() == b.ship_queue.size() and a.id < b.id))
	for y in yards:
		if _do(state, eid, CmdQueueShip.TYPE, {"station": y.id, "hull": "core:hull/colony_ship"}):
			return


# --- outposts and mining ---

static func _has_site(state: MatchState, eid: int, function: StringName) -> bool:
	for sid: int in state.stations.ordered():
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
	for sys_id: int in state.galaxy.systems.ordered():
		var sys := state.galaxy.system(sys_id)
		if sys.owner != StateIO.NONE:
			continue
		var near := false
		for lid in sys.lane_ids:
			if state.galaxy.system(state.galaxy.lane(lid).other_end(sys_id)).owner == eid:
				near = true
		if not near or state.pirate_bases.has(sys_id) or Pirates.raided_systems(state, eid).has(sys_id):
			continue
		var score := 0
		for pid in sys.planet_ids:
			var p := state.galaxy.planet(pid)
			score += _deposit_score(p) + 50 + int(p.deposits.get("core:resource/ore", 0)) * 100
			if _ore_site(state, p):
				score += ORE_SITE_SCORE  # Foundries need ore: belts and barren moons take mining stations
		if score > best_score:
			best = sys_id
			best_score = score
	if best != StateIO.NONE:
		_do(state, eid, CmdQueueStation.TYPE, {"planet": state.galaxy.system(best).planet_ids[0], "station": "core:station/outpost"})


static func _mining(state: MatchState, eid: int) -> void:
	_rare_earths_mine(state, eid)  # a colony building: not held up by an unfinished mining station
	if _has_site(state, eid, &"mining"):
		return
	var mining: Array = state.defs.defs("station").filter(func(d: StationDef) -> bool: return d.function == &"mining" and d.tier == 1)
	var used := {}  # planet -> stations orbiting it (one pass instead of one per check)
	for sid: int in state.stations.ordered():
		var pid := (state.stations.get_or(sid) as Station).planet_id
		used[pid] = int(used.get(pid, 0)) + 1
	# M4 WP14: deposit miners first, across every system (a rare earths belt gets the rare earths miner, not an
	# ore one): without rare earths, Fabricators make no components and shipyards stall. Then the rest.
	for deposit_pass in [true, false]:
		for sys_id: int in state.galaxy.systems.ordered():
			if state.galaxy.system(sys_id).owner != eid:
				continue
			for pid in state.galaxy.system(sys_id).planet_ids:
				var p := state.galaxy.planet(pid)
				if int(used.get(pid, 0)) >= p.orbital_slots:
					continue
				for def: StationDef in mining:
					if (def.requires_deposit != &"") != deposit_pass:
						continue
					if not def.placement.is_empty() and not StringName(p.planet_type) in def.placement:
						continue
					if def.requires_deposit != &"" and int(p.deposits.get(String(def.requires_deposit), 0)) <= 0:
						continue
					if _do(state, eid, CmdQueueStation.TYPE, {"planet": pid, "station": String(def.id)}):
						return


## M4 WP14: short of rare earths, a colony on a rare earths deposit builds a mine (governor templates don't).
static func _rare_earths_mine(state: MatchState, eid: int) -> void:
	if Deals.total_stock(state, eid, RARE_EARTHS) >= RARE_EARTHS_LOW * Stockpile.MILLI:
		return
	var is_mine := func(q: Construction) -> bool: return q.def_id == RE_MINE
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid and c.queue.any(is_mine):
			return  # one at a time
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		if c.owner != eid or c.buildings.has(RE_MINE):
			continue
		if _do(state, eid, CmdQueueBuilding.TYPE, {"planet": pid, "building": RE_MINE}):
			return


# --- freighters ---

static func _freighters(state: MatchState, eid: int) -> void:
	var total := 0
	var busy := 0
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner == eid and u.kind == "freighter" and u.home != StateIO.NONE:
			total += 1
			if not Freight.plan(state, u).is_empty():
				busy += 1
	if total > 0 and busy * 1000 <= total * BUSY_PERMILLE:
		return
	var berth_checked := {}  # system -> a free berth exists (one berth search per system)
	for sid: int in state.stations.ordered():
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
	for sid: int in state.stations.ordered():
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
	for pid: int in state.colonies.ordered():
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
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if s.owner == eid and (state.defs.get_def(StringName(s.def_id)) as StationDef).function == &"shipyard":
			count += 1
			have[s.planet_id] = true
	if count >= MIN_SHIPYARDS:
		return
	var best: Colony = null
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid and not have.has(pid) and (best == null or c.total_pops() > best.total_pops()):
			best = c
	if best != null:
		_do(state, eid, CmdQueueStation.TYPE, {"planet": best.id, "station": "core:station/shipyard_t1"})


# --- sector directive ---

static func _directive(state: MatchState, eid: int) -> void:
	var core := SectorLogistics.core_sector(state, eid)
	var e := state.empire(eid)
	var poor := e.credit_net < CREDIT_NET_LOW and int(e.treasury.get("core:resource/credits", 0)) < CREDIT_LOW
	var want := CREDIT_DIRECTIVE if poor else CORE_DIRECTIVE
	if core != null and core.directive != want:
		_do(state, eid, CmdSetDirective.TYPE, {"sector": core.id, "directive": want})
