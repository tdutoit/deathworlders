class_name MilitaryAutopilot
extends RefCounted
## Defensive autopilot for AI slots (M3 WP10; shared automation, D9). Monthly, after the economic rules:
##   1. merge idle fleets that share a system (no mission), so strength gathers;
##   2. send the nearest idle fleet strong enough (ai_attack_ratio by battle value) at each threat in own
##      territory: pirate raiders and bases, and warships of empires at war with it;
##   3. patrol the systems where convoys were lost in the last ai_loss_months, and escort the hub that lost
##      most, once losses reach ai_loss_trigger; drop the patrol when the losses stop;
##   4. once it has Autopilot.MIN_SHIPYARDS shipyards, at an idle one (never ahead of colony ships or freighters), build its species' standard designs (ai_build_classes,
##      in turn) while warship credit upkeep is under ai_military_share of the credit net before it, or the
##      fleet's battle value is under ai_min_fleet_value (cost-aware: pricier ships, fewer of them; M4 WP1).
## No offensives (M4). Orders go through Commands' validate/apply, like the economic autopilot.


static func month_tick(state: MatchState, eid: int, may_build: bool) -> void:
	var r := Fleets.rules(state)
	if r == null:
		return
	_merge(state, eid)
	var idle := _idle_fleets(state, eid)
	idle = _answer_threats(state, eid, idle, r)
	_convoys(state, eid, idle, r)
	if may_build:
		_build(state, eid, r)


## Own fleets with no mission that are neither moving nor in battle, by ID.
static func _idle_fleets(state: MatchState, eid: int) -> Array[Fleet]:
	var out: Array[Fleet] = []
	for fid: int in state.fleets.ordered():
		var f: Fleet = state.fleets.get_or(fid)
		if f.owner != eid or f.mission != "":
			continue
		var l := Fleets.lead(state, f)
		if l != null and not l.is_moving() and not Battles.in_battle(state, l.id):
			out.append(f)
	return out


static func strength(state: MatchState, f: Fleet) -> int:
	var total := 0
	for sid in f.ships():
		total += Battles.cost_of(state, sid)
	return total


static func _merge(state: MatchState, eid: int) -> void:
	var first := {}  # system -> fleet ID that takes the others
	for f in _idle_fleets(state, eid):
		var sys := Fleets.lead(state, f).system_id
		if not first.has(sys):
			first[sys] = f.id
		elif state.fleets.get_or(first[sys]) != null:
			Autopilot._do(state, eid, CmdMergeFleets.TYPE, {"into": first[sys], "from": f.id})


## {system: battle value} of hostiles in the empire's own systems, sorted by system ID.
static func threats(state: MatchState, eid: int) -> Dictionary:
	var by_system := {}
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner == eid or u.hp <= 0 or u.is_moving():
			continue
		if not (u.kind == "raider" or u.kind == "pirate_base" or u.kind == "warship"):
			continue
		if state.galaxy.system(u.system_id).owner != eid or not Battles.hostile(state, eid, u.owner):
			continue
		by_system[u.system_id] = int(by_system.get(u.system_id, 0)) + Battles.cost_of(state, u.id)
	var out := {}
	for sys: int in IdMap.sort_keys(by_system.keys()):
		out[sys] = by_system[sys]
	return out


## Sends fleets at threats; returns the fleets still idle.
static func _answer_threats(state: MatchState, eid: int, idle: Array[Fleet], r: CombatRulesDef) -> Array[Fleet]:
	var t := threats(state, eid)
	for sys: int in t:
		var dist := AutoLogistics._hops_from(state, sys, {})
		var best: Fleet = null
		var best_hops := 0
		for f in idle:
			if strength(state, f) * 1000 < int(t[sys]) * r.ai_attack_ratio:
				continue
			var hops := int(dist.get(Fleets.lead(state, f).system_id, Sectors.FAR))
			if hops < Sectors.FAR and (best == null or hops < best_hops):
				best = f
				best_hops = hops
		if best != null:
			if Fleets.lead(state, best).system_id == sys or Autopilot._do(state, eid, CmdMoveFleet.TYPE, {"fleet": best.id, "to": sys}):
				idle.erase(best)
	return idle


static func _convoys(state: MatchState, eid: int, idle: Array[Fleet], r: CombatRulesDef) -> void:
	var e := state.empire(eid)
	var since := state.tick - r.ai_loss_months * Calendar.HOURS_PER_MONTH
	var systems := {}
	var by_hub := {}
	var count := 0
	for l: Dictionary in e.losses:
		if int(l["tick"]) < since:
			continue
		count += 1
		systems[int(l["system"])] = true
		var hub := int(l.get("hub", StateIO.NONE))
		if hub != StateIO.NONE:
			by_hub[hub] = int(by_hub.get(hub, 0)) + 1
	var patrol: Fleet = null
	var escorts := {}
	for fid: int in state.fleets.ordered():
		var f: Fleet = state.fleets.get_or(fid)
		if f.owner == eid and f.mission == "patrol" and patrol == null:
			patrol = f
		elif f.owner == eid and f.mission == "escort":
			escorts[f.escort_hub] = f
	if count < r.ai_loss_trigger:
		if patrol != null:
			Autopilot._do(state, eid, CmdSetPatrol.TYPE, {"fleet": patrol.id, "systems": []})
		for hub: int in IdMap.sort_keys(escorts.keys()):
			Autopilot._do(state, eid, CmdSetEscort.TYPE, {"fleet": (escorts[hub] as Fleet).id, "hub": 0})
		return
	var list: Array[int] = []
	for sys: int in IdMap.sort_keys(systems.keys()):
		if list.size() < CmdSetPatrol.MAX_SYSTEMS:
			list.append(sys)
	if patrol == null and not idle.is_empty():
		patrol = idle.pop_front()
	if patrol != null and patrol.patrol != list:
		Autopilot._do(state, eid, CmdSetPatrol.TYPE, {"fleet": patrol.id, "systems": list})
	var worst := StateIO.NONE
	for hub: int in IdMap.sort_keys(by_hub.keys()):
		if worst == StateIO.NONE or int(by_hub[hub]) > int(by_hub[worst]):
			worst = hub
	if worst != StateIO.NONE and not escorts.has(worst) and not idle.is_empty():
		Autopilot._do(state, eid, CmdSetEscort.TYPE, {"fleet": idle.pop_front().id, "hub": worst})


static func _build(state: MatchState, eid: int, r: CombatRulesDef) -> void:
	var yards := 0
	for sid: int in state.stations.ordered():
		var y: Station = state.stations.get_or(sid)
		if y.owner == eid and y.operational and (state.defs.get_def(StringName(y.def_id)) as StationDef).function == &"shipyard":
			yards += 1
	if yards < Autopilot.MIN_SHIPYARDS:
		return  # the economy's shipyards come first (B20)
	var ships := 0  # battle value of the fleet
	var count := 0
	var upkeep := 0
	var queued := 0
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner == eid and u.kind == "warship":
			ships += Battles.cost_of(state, u.id)  # battle value, so pricier species build fewer ships
			count += 1
			upkeep += (state.defs.get_def(StringName(u.hull_id)) as HullDef).credit_upkeep_milli
	for sid: int in state.stations.ordered():
		var y: Station = state.stations.get_or(sid)
		if y.owner == eid:
			queued += y.ship_queue.filter(func(q: Construction) -> bool: return q.design != 0).size()
	if queued > 0:
		return  # one warship at a time
	var e := state.empire(eid)
	var budget := FixedMath.floor_div((e.credit_net + upkeep) * r.ai_military_share, 1000)
	if ships >= r.ai_min_fleet_value and (upkeep >= budget or not threatened(state, eid, r)):
		return
	var by_class := {}  # hull class -> own standard design ID
	for did: int in state.designs.ordered():
		var d: ShipDesign = state.designs.get_or(did)
		if d.owner == eid and d.source != "":
			var h := state.defs.get_def(StringName(d.hull)) as HullDef
			if h != null and not by_class.has(String(h.hull_class)):
				by_class[String(h.hull_class)] = d.id
	var n := r.ai_build_classes.size()
	for i in n:
		var cls := String(r.ai_build_classes[posmod(count + i, n)])
		if not by_class.has(cls):
			continue
		for sid: int in state.stations.ordered():
			var y: Station = state.stations.get_or(sid)
			if y.owner == eid and y.ship_queue.is_empty() 					and Autopilot._do(state, eid, CmdQueueShip.TYPE, {"station": y.id, "design": by_class[cls]}):
				return


## Raiders hunting the empire, convoys lost in the last ai_loss_months, or a war: worth more warships.
static func threatened(state: MatchState, eid: int, r: CombatRulesDef) -> bool:
	if Pirates.raiders_hunting(state, eid) > 0:
		return true
	var since := state.tick - r.ai_loss_months * Calendar.HOURS_PER_MONTH
	for l: Dictionary in state.empire(eid).losses:
		if int(l["tick"]) >= since:
			return true
	for key: String in state.wars:
		if int(key.get_slice(":", 0)) == eid or int(key.get_slice(":", 1)) == eid:
			return true
	return false
