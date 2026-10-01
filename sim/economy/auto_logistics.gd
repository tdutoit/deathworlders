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
	for eid: int in state.empires:
		_assign(state, eid)


## What auto-logistics must leave at a holder: the player's reserve, or the default share of the cap.
static func reserve_milli(state: MatchState, holder: int, res: String) -> int:
	var key := "%d:%s" % [holder, res]
	if state.reserves.has(key):
		return int(state.reserves[key]) * Stockpile.MILLI
	var cap := Holders.cap_milli(state, holder, res)
	return FixedMath.mul_permille(cap, Economy.rules(state.defs).reserve_default_permille) if cap > 0 else 0


## Open demands of an empire: [{holder, resource, target (milli), priority}], explicit and construction.
static func demands_of(state: MatchState, eid: int) -> Array:
	var out := []
	for did: int in state.demands:
		var d: Demand = state.demands.get_or(did)
		if d.owner == eid:
			out.append({"holder": d.holder, "resource": d.resource, "target": d.target * Stockpile.MILLI, "priority": d.priority})
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid and not c.queue.is_empty():
			_build_needs(out, c.id, [c.queue[0]])
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if s.owner != eid:
			continue
		if s.build != null:
			_build_needs(out, s.id, [s.build])
		if not s.ship_queue.is_empty() and s.operational:
			var docks := (state.defs.get_def(StringName(s.def_id)) as StationDef).docks
			_build_needs(out, s.id, s.ship_queue.slice(0, docks))
	return out


static func _build_needs(out: Array, holder: int, builds: Array) -> void:
	var need := {}
	for b: Construction in builds:
		var paid := b.paid()
		for res: String in b.cost:
			need[res] = need.get(res, 0) + int(b.cost[res]) - int(paid.get(res, 0))
	for res: String in IdMap.sort_keys(need.keys()):
		if need[res] > 0:
			out.append({"holder": holder, "resource": res, "target": need[res], "priority": 2})


static func _assign(state: MatchState, eid: int) -> void:
	var in_transit := {}  # "holder:res" -> milli heading there
	var promised := {}  # "holder:res" -> milli that auto jobs will still pick up there
	var idle: Array[Unit] = []
	for uid: int in state.units:
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
	for d: Dictionary in demands_of(state, eid):
		var key := "%d:%s" % [d["holder"], d["resource"]]
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
	for d: Dictionary in open:
		while d["deficit"] > 0 and not idle.is_empty():
			var assigned := false
			for src in _sources(state, holders, d, promised, hops):
				var f := _pick_freighter(state, idle, src, d["holder"], hops)
				if f == null:
					continue
				var load := mini(mini(Freight.capacity_milli(state, f), d["deficit"]), _surplus(state, src, d["resource"], promised))
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
	for pid: int in state.colonies:
		if (state.colonies.get_or(pid) as Colony).owner == eid:
			out.append(pid)
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if s.owner == eid and s.operational:
			out.append(sid)
	out.sort()
	return out


static func _surplus(state: MatchState, holder: int, res: String, promised: Dictionary) -> int:
	var stock := Holders.stockpile(state, holder).milli(res)
	return stock - reserve_milli(state, holder, res) - int(promised.get("%d:%s" % [holder, res], 0))


## Sources with surplus for a demand, nearest first (same system by impulse days, then by lanes), then ID.
static func _sources(state: MatchState, holders: Array[int], d: Dictionary, promised: Dictionary, hops: Dictionary) -> Array[int]:
	var dest_sys := Holders.system(state, d["holder"])
	var dest_body := Holders.body(state, d["holder"])
	var scored := []
	for h in holders:
		if h == d["holder"] or _surplus(state, h, d["resource"], promised) <= 0:
			continue
		var sys := Holders.system(state, h)
		var dist := Holders.impulse_days(state, Holders.body(state, h), dest_body) if sys == dest_sys \
				else 1000 + int(_hops_from(state, dest_sys, hops).get(sys, FAR))
		scored.append([dist, h])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array[int] = []
	for s: Array in scored:
		out.append(s[1])
	return out


## The idle freighter nearest the source whose hub range covers source and destination (B8).
static func _pick_freighter(state: MatchState, idle: Array[Unit], src: int, dest: int, hops: Dictionary) -> Unit:
	var src_sys := Holders.system(state, src)
	var dest_sys := Holders.system(state, dest)
	var best: Unit = null
	var best_dist := FAR
	for u in idle:
		var hub_hops := _hops_from(state, Holders.system(state, u.home), hops)
		var reach := hub_range(state, u.home)
		if int(hub_hops.get(src_sys, FAR)) > reach or int(hub_hops.get(dest_sys, FAR)) > reach:
			continue
		var dist := int(_hops_from(state, u.system_id, hops).get(src_sys, FAR)) * 100
		if u.system_id == src_sys and u.body != StateIO.NONE:
			dist += Holders.impulse_days(state, u.body, Holders.body(state, src))
		if best == null or dist < best_dist or (dist == best_dist and u.id < best.id):
			best = u
			best_dist = dist
	return best


## Lanes a hub's freighters serve: the logistics station's tier range, or the rules' range for a colony hub.
static func hub_range(state: MatchState, hub: int) -> int:
	var s := state.station(hub)
	if s != null:
		return (state.defs.get_def(StringName(s.def_id)) as StationDef).hub_range
	return Economy.rules(state.defs).colony_hub_range


static func _hops_from(state: MatchState, system_id: int, cache: Dictionary) -> Dictionary:
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
