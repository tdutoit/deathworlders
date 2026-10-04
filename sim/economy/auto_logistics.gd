class_name AutoLogistics
extends RefCounted
## Auto-logistics (Sub-spec B8), each day tick, per empire in ID order:
##   1. Open demands: explicit Demand targets plus every active build's remaining materials (construction
##      sites feed themselves); deficit = target - (stock + in transit).
##   2. Sorted by (priority desc, deficit desc, holder ID asc).
##   3. Sources with surplus (stock - reserve - already promised) sorted by travel distance, then ID.
##   4. Idle berthed freighters whose hub range covers both ends, sorted by distance to the source, then ID;
##      load = min(capacity, deficit, surplus) as a one-shot job.
##   5. Repeat until no idle freighters or no demands.

const FAR := 1 << 20


static func day_tick(state: MatchState) -> void:
	for eid: int in state.empires.ordered():
		_assign(state, eid)


## One empire's daily assignment (the sim staggers empires over the day's first hours, Sim._logistics_hour).
static func empire_day(state: MatchState, eid: int) -> void:
	_assign(state, eid)


## What auto-logistics must leave at a holder: the player's reserve, or the default share of the cap.
static func reserve_milli(state: MatchState, holder: int, res: String, mods_cache: Variant = null) -> int:
	var key := "%d:%s" % [holder, res]
	if state.reserves.has(key):
		return int(state.reserves[key]) * Stockpile.MILLI
	var cap := Holders.cap_milli(state, holder, res, mods_cache)
	return FixedMath.mul_permille(cap, Economy.rules(state.defs).reserve_default_permille) if cap > 0 else 0


## Open demands of an empire: [{holder, resource, target (milli), priority}] from player targets, builds and
## the sector governors. Optional keys limit the sources: "sector" (sector ID) and/or "sources" (holder IDs).
static func demands_of(state: MatchState, eid: int) -> Array:
	var out := []
	for did: int in state.demands.ordered():
		var d: Demand = state.demands.get_or(did)
		if d.owner == eid:
			out.append({"holder": d.holder, "resource": d.resource, "target": d.target * Stockpile.MILLI, "priority": d.priority})
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid and not c.queue.is_empty():
			_build_needs(out, c.id, [c.queue[0]])
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if s.owner != eid:
			continue
		if s.build != null:
			_build_needs(out, s.id, [s.build])
		if not s.ship_queue.is_empty() and s.operational:
			var docks := (state.defs.get_def(StringName(s.def_id)) as StationDef).docks
			_build_needs(out, s.id, s.ship_queue.slice(0, docks))
	out.append_array(SectorLogistics.demands(state, eid))
	return out


static func _build_needs(out: Array, holder: int, builds: Array) -> void:
	var need := {}
	for b: Construction in builds:
		var paid := b.paid()
		for res: String in b.cost:
			need[res] = need.get(res, 0) + int(b.cost[res]) - int(paid.get(res, 0))
	for res: String in IdMap.sort_keys(need.keys()):
		if need[res] > 0:
			out.append({"holder": holder, "resource": res, "target": need[res], "priority": 2, "build": true})


static func _assign(state: MatchState, eid: int) -> void:
	var in_transit := {}  # "holder:res" -> milli heading there
	var promised := {}  # "holder:res" -> milli that auto jobs will still pick up there
	var idle: Array[Unit] = []
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner != eid or u.kind != "freighter":
			continue
		var p := Freight.plan(state, u)
		if p.is_empty():
			if u.home != StateIO.NONE and u.phase == "" and u.wait_hours == 0 and not u.is_moving():
				idle.append(u)
			continue
		var key := "%d:%s" % [p["dest"], p["resource"]]
		var carried: int = u.cargo.get(p["resource"], 0)
		var not_loaded: bool = p["auto"] and u.phase in ["to_source", "loading"]
		in_transit[key] = in_transit.get(key, 0) + (int(p["amount"]) if not_loaded else carried)
		if not_loaded:
			var src_key := "%d:%s" % [p["source"], p["resource"]]
			promised[src_key] = promised.get(src_key, 0) + int(p["amount"])
	if idle.is_empty():
		return
	var open := []
	var raided := Pirates.raided_systems(state, eid)
	for d: Dictionary in demands_of(state, eid):
		var key := "%d:%s" % [d["holder"], d["resource"]]
		if d.get("build", false):
			promised[key] = promised.get(key, 0) + int(d["target"])  # a site's materials are earmarked, never surplus
		if raided.has(Holders.system(state, d["holder"])):
			continue
		var stock := Holders.stockpile(state, d["holder"]).milli(d["resource"])
		var deficit: int = d["target"] - stock - in_transit.get(key, 0)
		if deficit > 0:
			d["deficit"] = deficit
			open.append(d)
	open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["priority"] != b["priority"]:
			return a["priority"] > b["priority"]
		if a["deficit"] != b["deficit"]:
			return a["deficit"] > b["deficit"]
		return a["holder"] < b["holder"])
	var holders := _own_holders(state, eid)
	var hops := {}  # system -> {system: lanes}, filled on demand
	var cut := {}  # "from>to" -> blocked by raiders (B8 route safety), filled on demand
	var base := {}  # "holder:res" -> stock minus reserve; stocks and caps don't change during assignment
	var min_cap := FAR  # smallest idle hold: a lower bound for every freighter's minimum load below
	for u in idle:
		min_cap = mini(min_cap, Freight.capacity_milli(state, u))
	var trip_permille := Economy.rules(state.defs).min_trip_permille
	for d: Dictionary in open:
		# A non-build deficit under every freighter's minimum load can't pass the load test from any source:
		# skip the source search (same outcome as the per-source test below, which it bounds).
		if not d.get("build", false) and int(d["deficit"]) < mini(FixedMath.mul_permille(min_cap, trip_permille), int(d["target"]) / 2):
			continue
		while d["deficit"] > 0 and not idle.is_empty():
			var assigned := false
			for src in _sources(state, holders, d, promised, hops, base, raided):
				var src_sys := _sys_of(state, base, src)
				var dest_sys := _sys_of(state, base, d["holder"])
				var leg := "%d>%d" % [src_sys, dest_sys]
				if not cut.has(leg):
					cut[leg] = Freight.blocked(state, eid, src_sys, dest_sys)
				if cut[leg]:
					continue
				# Same test as below, before the freighter search: if no idle freighter could take a load worth
				# the trip from here, skip the source (identical outcome, far cheaper with many idle freighters).
				var upper := mini(int(d["deficit"]), _surplus(state, src, d["resource"], promised, base))
				var finishing: bool = d.get("build", false) and int(d["deficit"]) <= upper
				if not finishing and upper < mini(FixedMath.mul_permille(min_cap, trip_permille), int(d["target"]) / 2):
					continue
				var f := _pick_freighter(state, idle, src, d["holder"], hops, base)
				if f == null:
					continue
				var load := mini(mini(Freight.capacity_milli(state, f), d["deficit"]), _surplus(state, src, d["resource"], promised, base))
				# Not worth a trip yet (the deficit keeps growing): under min_trip of capacity and under half the target.
				# Critical demands too, or daily consumption sends a freighter per day. Builds may send a small load
				# that covers all they still lack (their target shrinks with the stock, so it would never grow).
				var min_load := mini(FixedMath.mul_permille(Freight.capacity_milli(state, f), Economy.rules(state.defs).min_trip_permille),
						int(d["target"]) / 2)
				if load < min_load and not (d.get("build", false) and load == d["deficit"]):
					continue  # builds: small loads only to finish the site; otherwise pool the surplus
				f.job = {"source": src, "dest": d["holder"], "resource": d["resource"], "amount": load}
				f.phase = "to_source"
				idle.erase(f)
				var src_key := "%d:%s" % [src, d["resource"]]
				promised[src_key] = promised.get(src_key, 0) + load
				d["deficit"] -= load
				assigned = true
				break
			if not assigned:
				break


static func _own_holders(state: MatchState, eid: int) -> Array[int]:
	var out: Array[int] = []
	for pid: int in state.colonies.ordered():
		if (state.colonies.get_or(pid) as Colony).owner == eid:
			out.append(pid)
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if s.owner == eid and s.operational:
			out.append(sid)
	out.sort()
	return out


## Stock minus reserve minus what auto jobs will still pick up. `base` (optional) caches stock minus reserve
## per holder and resource for one assignment pass (cap lookups resolve planet modifiers: not cheap).
static func _surplus(state: MatchState, holder: int, res: String, promised: Dictionary, base: Variant = null) -> int:
	var key := "%d:%s" % [holder, res]
	var free: int
	if base != null and (base as Dictionary).has(key):
		free = base[key]
	else:
		var mods_cache: Variant = null
		if base != null:
			if not (base as Dictionary).has("mods"):
				base["mods"] = {}
			mods_cache = base["mods"]
		free = Holders.stockpile(state, holder).milli(res) - reserve_milli(state, holder, res, mods_cache)
		if base != null:
			base[key] = free
	return free - int(promised.get(key, 0))


## Sources with surplus for a demand, nearest first (same system by impulse days, then by lanes), then ID.
static func _sources(state: MatchState, holders: Array[int], d: Dictionary, promised: Dictionary, hops: Dictionary,
		base: Dictionary, raided: Dictionary) -> Array[int]:
	var dest_sys := _sys_of(state, base, d["holder"])
	var dest_body := _body_of(state, base, d["holder"])
	var scored := []
	var in_sector: Dictionary = {}  # {system: true} of the demand's sector, once per pass
	var limited := d.has("sector")
	if limited:
		var sec_key := "sec:%d" % int(d["sector"])
		if not base.has(sec_key):
			var set := {}
			var sector: Sector = state.sectors.get_or(d["sector"])
			if sector != null:
				for sys_id in sector.systems:
					set[sys_id] = true
			base[sec_key] = set
		in_sector = base[sec_key]
	var cand_key := "cand:" + String(d["resource"])  # holders with any surplus before promises, once per pass
	if not base.has(cand_key):
		if not base.has("hinfo"):  # [holder, stockpile, system, body, colony, its mods, station], once per pass
			var info := []
			for h in holders:
				var c := state.colony(h)
				info.append([h, Holders.stockpile(state, h), _sys_of(state, base, h), _body_of(state, base, h), c,
					PlanetMods.of(state, c) if c != null else null, state.station(h)])
			base["hinfo"] = info
		var cand := []  # [holder, "holder:res" key, system, body, stock minus reserve]
		var res: String = d["resource"]
		var reserve_permille := Economy.rules(state.defs).reserve_default_permille
		for hi: Array in base["hinfo"]:
			var stock := (hi[1] as Stockpile).milli(res)
			if stock <= 0:
				continue  # no stock means no surplus whatever the reserve (>= 0)
			# Same value as _surplus / reserve_milli, without their per-call lookups.
			var key := "%d:%s" % [hi[0], res]
			var reserve: int
			if state.reserves.has(key):
				reserve = int(state.reserves[key]) * Stockpile.MILLI
			else:
				var cap := Economy.cap_milli(hi[4], state.defs, hi[5], res) if hi[4] != null \
						else (StationOps.cap_milli(state, hi[6], res) if hi[6] != null else 0)
				reserve = FixedMath.mul_permille(cap, reserve_permille) if cap > 0 else 0
			var free := stock - reserve
			base[key] = free
			if free > 0:
				cand.append([hi[0], key, hi[2], hi[3], free])
		base[cand_key] = cand
	var dest_hops := {}
	for entry: Array in base[cand_key]:
		var h: int = entry[0]
		if h == d["holder"] or int(entry[4]) - int(promised.get(entry[1], 0)) <= 0:
			continue
		if d.has("sources") and not h in d["sources"]:
			continue
		var sys: int = entry[2]
		if limited and not in_sector.has(sys):
			continue
		if raided.has(sys):  # own holders only: the empire's raided set
			continue
		var dist: int
		if sys == dest_sys:
			dist = Holders.impulse_days(state, entry[3], dest_body)
		else:
			if dest_hops.is_empty():
				dest_hops = _hops_from(state, dest_sys, hops)
			dist = 1000 + int(dest_hops.get(sys, FAR))
		scored.append([dist, h])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array[int] = []
	for s: Array in scored:
		out.append(s[1])
	return out


## The idle freighter nearest the source whose hub range covers source and destination (B8).
static func _pick_freighter(state: MatchState, idle: Array[Unit], src: int, dest: int, hops: Dictionary,
		base: Dictionary = {}) -> Unit:
	var src_sys := _sys_of(state, base, src)
	var dest_sys := _sys_of(state, base, dest)
	var best: Unit = null
	var best_dist := FAR
	for u in idle:
		var hub_key := "hub:%d" % u.home  # [lanes from the home hub, its range], once per pass
		if not base.has(hub_key):
			base[hub_key] = [_hops_from(state, Holders.system(state, u.home), hops), hub_range(state, u.home)]
		var hub_hops: Dictionary = base[hub_key][0]
		var reach: int = base[hub_key][1]
		if int(hub_hops.get(src_sys, FAR)) > reach or int(hub_hops.get(dest_sys, FAR)) > reach:
			continue
		var dist := int(_hops_from(state, u.system_id, hops).get(src_sys, FAR)) * 100
		if u.system_id == src_sys and u.body != StateIO.NONE:
			dist += Holders.impulse_days(state, u.body, Holders.body(state, src))
		if best == null or dist < best_dist or (dist == best_dist and u.id < best.id):
			best = u
			best_dist = dist
	return best


## A holder's system, cached for one assignment pass in `base` (Holders.system looks up colony then station).
static func _sys_of(state: MatchState, base: Dictionary, h: int) -> int:
	var key := "sys:%d" % h
	if not base.has(key):
		base[key] = Holders.system(state, h)
	return base[key]


## A holder's body, cached for one assignment pass in `base`.
static func _body_of(state: MatchState, base: Dictionary, h: int) -> int:
	var key := "body:%d" % h
	if not base.has(key):
		base[key] = Holders.body(state, h)
	return base[key]


## Lanes a hub's freighters serve: the logistics station's tier range, or the rules' range for a colony hub.
static func hub_range(state: MatchState, hub: int) -> int:
	var s := state.station(hub)
	if s != null:
		return (state.defs.get_def(StringName(s.def_id)) as StationDef).hub_range
	return Economy.rules(state.defs).colony_hub_range


## Lanes from a system to every system within max_depth lanes (cheap on big maps when the range is small).
static func hops_within(state: MatchState, system_id: int, max_depth: int, cache: Dictionary) -> Dictionary:
	var key := "%d/%d" % [system_id, max_depth]
	if not cache.has(key):
		var dist := {system_id: 0}
		var queue: Array[int] = [system_id]
		while not queue.is_empty():
			var at: int = queue.pop_front()
			if dist[at] >= max_depth:
				continue
			for lid in state.galaxy.system(at).lane_ids:
				var nxt := state.galaxy.lane(lid).other_end(at)
				if not dist.has(nxt):
					dist[nxt] = dist[at] + 1
					queue.append(nxt)
		cache[key] = dist
	return cache[key]


## Lanes from a system to every reachable system. Cached on the state for the whole match (lanes are fixed);
## `_cache` is kept for the callers' signatures.
static func _hops_from(state: MatchState, system_id: int, _cache: Dictionary) -> Dictionary:
	var cache := state.hop_cache
	if not cache.has(system_id):
		var dist := {system_id: 0}
		var queue: Array[int] = [system_id]
		while not queue.is_empty():
			var at: int = queue.pop_front()
			for lid in state.galaxy.system(at).lane_ids:
				var nxt := state.galaxy.lane(lid).other_end(at)
				if not dist.has(nxt):
					dist[nxt] = dist[at] + 1
					queue.append(nxt)
		cache[system_id] = dist
	return cache[system_id]
