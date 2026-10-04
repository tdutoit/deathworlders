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
## M4 WP11 (war operations): threats in allied and protected systems count like own ones (calls to arms and
## guardian duty); fleets under ai_repair_hull of their hull go home to repair; at war, idle fleets beyond a
## home reserve (Caution x ai_reserve_per_caution permille of the fleet value) attack: enemy fleets they beat
## by ai_attack_ratio first, then undefended enemy colony systems (blockades score war points), nearest first.
## Orders go through Commands' validate/apply, like the economic autopilot.


static func month_tick(state: MatchState, eid: int, may_build: bool) -> void:
	var r := Fleets.rules(state)
	if r == null:
		return
	_merge(state, eid)
	_footing(state, eid)
	_scout(state, eid)
	var idle := _idle_fleets(state, eid)
	idle = _answer_threats(state, eid, idle, r)
	idle = _repair(state, eid, idle)
	idle = _offensive(state, eid, idle, r)
	_convoys(state, eid, idle, r)
	if may_build:
		_build(state, eid, r)


## Idle scouts fly to the nearest system of an empire not met yet (first contact, E1), as a player would; nearest
## by lanes, then system ID. M4 WP14: without it, AI empires many lanes apart never met.
static func _scout(state: MatchState, eid: int) -> void:
	var hops := {}
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner != eid or u.kind != "scout" or u.is_moving():
			continue
		var dist := AutoLogistics._hops_from(state, u.system_id, hops)
		var best := StateIO.NONE
		for sid: int in state.galaxy.systems.ordered():
			var o := state.galaxy.system(sid).owner
			if o == StateIO.NONE or o == eid or not state.empires.has(o) or Relations.has_contact(state, eid, o) or not dist.has(sid):
				continue
			if best == StateIO.NONE or int(dist[sid]) < int(dist[best]):
				best = sid
		if best != StateIO.NONE and best != u.system_id:
			Autopilot._do(state, eid, CmdMoveUnit.TYPE, {"unit": u.id, "to": best})


## Damaged fleets head for the nearest own shipyard system to repair (A13 docked repair).
static func _repair(state: MatchState, eid: int, idle: Array[Fleet]) -> Array[Fleet]:
	var ar := StrategicAI.rules(state)
	if ar == null:
		return idle
	var yards: Array[int] = []
	for sid: int in state.stations.ordered():
		var st: Station = state.stations.get_or(sid)
		if st.owner == eid and st.operational and (state.defs.get_def(StringName(st.def_id)) as StationDef).function == &"shipyard":
			yards.append(st.system_id)
	if yards.is_empty():
		return idle
	var keep: Array[Fleet] = []
	for f in idle:
		var c := _condition(state, f)
		var l := Fleets.lead(state, f)
		if c[1] > 0 and c[0] * 1000 < c[1] * ar.repair_hull and not l.system_id in yards:
			var dist := AutoLogistics._hops_from(state, l.system_id, {})
			var best := yards[0]
			for y in yards:
				if int(dist.get(y, Sectors.FAR)) < int(dist.get(best, Sectors.FAR)):
					best = y
			if Autopilot._do(state, eid, CmdMoveFleet.TYPE, {"fleet": f.id, "to": best}):
				continue
		keep.append(f)
	return keep


## [hull now, hull max] of a fleet.
static func _condition(state: MatchState, f: Fleet) -> Array[int]:
	var out: Array[int] = [0, 0]
	for sid in f.ships():
		var u: Unit = state.units.get_or(sid)
		out[0] += u.hp
		out[1] += ShipStats.cached(state.defs, u.hull_id, u.components, SpeciesTraits.source_of(state, u.owner)).hull
	return out


## At war: attack with idle fleets beyond the home reserve (WP11).
static func _offensive(state: MatchState, eid: int, idle: Array[Fleet], r: CombatRulesDef) -> Array[Fleet]:
	var ar := StrategicAI.rules(state)
	if ar == null or idle.is_empty():
		return idle
	var enemies: Array[int] = []
	for wid: int in state.war_info.ordered():
		var w: War = state.war_info.get_or(wid)
		if w.attacker == eid:
			enemies.append(w.defender)
		elif w.defender == eid:
			enemies.append(w.attacker)
	if enemies.is_empty():
		return idle
	var total := Treaties.power(state, eid)
	var reserve := FixedMath.floor_div(total * Treaties.personality(state, eid, "caution") * ar.reserve_per_caution, 1000)
	var idle_value := 0
	for f in idle:
		idle_value += strength(state, f)
	var targets := _targets(state, enemies)  # [[system, defending value, kind order], ...]
	var keep: Array[Fleet] = []
	var sent := {}
	for f in idle:
		var fv := strength(state, f)
		if total - fv < reserve or idle_value - fv < 0:
			keep.append(f)
			continue
		var l := Fleets.lead(state, f)
		var dist := AutoLogistics._hops_from(state, l.system_id, {})
		var best := -1
		var best_key := Sectors.FAR
		for t: Array in targets:
			if sent.has(t[0]) or fv * 1000 < int(t[1]) * r.ai_attack_ratio:
				continue
			var key := int(t[2]) * 10000 + int(dist.get(t[0], Sectors.FAR))
			if key < best_key:
				best = t[0]
				best_key = key
		if best >= 0 and Autopilot._do(state, eid, CmdMoveFleet.TYPE, {"fleet": f.id, "to": best}):
			sent[best] = true
			total -= fv
			continue
		keep.append(f)
	return keep


## Offensive targets: systems where enemy warships sit (kind 0, their value) and enemy colony systems with no
## enemy warships (kind 1, value 0), in system ID order.
static func _targets(state: MatchState, enemies: Array[int]) -> Array:
	var value := {}
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner in enemies and u.kind == "warship" and not u.is_moving():
			value[u.system_id] = int(value.get(u.system_id, 0)) + Battles.cost_of(state, u.id)
	var out := []
	for sid: int in IdMap.sort_keys(value.keys()):
		out.append([sid, value[sid], 0])
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		var sid := state.galaxy.planet(pid).system_id
		if c.owner in enemies and not value.has(sid):
			var defended := 0
			for stid: int in state.stations.ordered():
				var st: Station = state.stations.get_or(stid)
				if st.system_id == sid and st.owner in enemies and Battles.is_armed_station(state, st):
					defended += Battles.cost_of(state, st.id)
			out.append([sid, defended, 1])
			value[sid] = defended
	return out


static func _at_war(state: MatchState, eid: int) -> bool:
	for k: String in state.wars.keys():  # any order: only a yes/no
		if int(k.get_slice(":", 0)) == eid or int(k.get_slice(":", 1)) == eid:
			return true
	return false


## True when a colony building or station site of the empire has waited for materials over ai_civilian_stall_days.
## Freighters serve the largest deficit first, so a warship build would otherwise take every alloy (WP14).
## Sites in raided systems don't count: freighters skip them until warships clear the raiders.
static func _civilian_stalled(state: MatchState, eid: int, r: CombatRulesDef) -> bool:
	var raided := Pirates.raided_systems(state, eid)
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid and not c.queue.is_empty() and (c.queue[0] as Construction).stalled_days > r.ai_civilian_stall_days \
				and not raided.has(state.galaxy.planet(pid).system_id):
			return true
	for sid: int in state.stations.ordered():
		var st: Station = state.stations.get_or(sid)
		if st.owner == eid and st.build != null and st.build.stalled_days > r.ai_civilian_stall_days and not raided.has(st.system_id):
			return true
	return false


## True when the empire holds the design's whole cost in stock (alloys, components...), so the build won't stall
## the shipyard queue in front of freighters and colony ships.
static func _can_afford(state: MatchState, eid: int, design_id: int) -> bool:
	var d: ShipDesign = state.designs.get_or(design_id)
	var cost := ShipStats.cost(state.defs, d.hull, d.components)
	for res: String in cost:
		if Deals.total_stock(state, eid, res) < int(cost[res]) * Stockpile.MILLI:
			return false
	return true


## D7 for AI slots (until the strategic AI, WP10): Peace when at peace; at war Mobilised, or Total War when an
## enemy is stronger.
static func _footing(state: MatchState, eid: int) -> void:
	var want := WarFooting.PEACE
	for wid: int in state.war_info.ordered():
		var w: War = state.war_info.get_or(wid)
		if w.attacker != eid and w.defender != eid:
			continue
		var enemy := w.defender if w.attacker == eid else w.attacker
		if Treaties.power(state, enemy) > Treaties.power(state, eid):
			want = "core:war_footing/total_war"
			break
		want = "core:war_footing/mobilised"
	if state.empire(eid).footing != want:
		Autopilot._do(state, eid, CmdSetWarFooting.TYPE, {"footing": want})


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


## {system: battle value} of hostiles in the empire's own systems (and, from WP11, its allies' and protected's),
## sorted by system ID.
static func threats(state: MatchState, eid: int) -> Dictionary:
	var by_system := {}
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner == eid or u.hp <= 0 or u.is_moving():
			continue
		if not (u.kind == "raider" or u.kind == "pirate_base" or u.kind == "warship"):
			continue
		var owner := state.galaxy.system(u.system_id).owner
		var ours := owner == eid or (owner != StateIO.NONE and owner >= 0 and Treaties.allied(state, eid, owner)
			and Battles.hostile(state, owner, u.owner))  # WP11: allies and protected count as our own
		if not ours or not Battles.hostile(state, eid, u.owner):
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
			queued += y.ship_queue.size()  # warships, and civilian ships (colony ships, freighters) come first (WP14)
	if queued > 0:
		return  # one at a time, and never ahead of a civilian ship
	if ships * 2 >= r.ai_min_fleet_value and not _at_war(state, eid) and _civilian_stalled(state, eid, r):
		return  # past half the minimum fleet, at peace, a stalled farm, outpost or mining site gets the alloys first (WP14)
	var e := state.empire(eid)
	var budget := FixedMath.floor_div((e.credit_net + upkeep) * r.ai_military_share, 1000)
	if ships >= r.ai_min_fleet_value and (upkeep >= budget or not threatened(state, eid, r)):
		return
	var by_class := {}  # hull class -> own standard design ID, the highest Mk its research allows (M5)
	var mark := {}
	for did: int in state.designs.ordered():
		var d: ShipDesign = state.designs.get_or(did)
		if d.owner == eid and d.source != "" and Shipyards.design_tech(state, eid, d) == "":
			var h := state.defs.get_def(StringName(d.hull)) as HullDef
			if h != null and h.mark > int(mark.get(String(h.hull_class), 0)):
				by_class[String(h.hull_class)] = d.id
				mark[String(h.hull_class)] = h.mark
	var n := r.ai_build_classes.size()
	for i in n:
		var cls := String(r.ai_build_classes[posmod(count + i, n)])
		if not by_class.has(cls) or not _can_afford(state, eid, by_class[cls]):
			continue  # M4 WP14: never start a warship the empire can't pay for (it would stall the yard for years)
		for sid: int in state.stations.ordered():
			var y: Station = state.stations.get_or(sid)
			if y.owner == eid and y.ship_queue.is_empty() \
					and Autopilot._do(state, eid, CmdQueueShip.TYPE, {"station": y.id, "design": by_class[cls]}):
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
