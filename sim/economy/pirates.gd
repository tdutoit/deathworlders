class_name Pirates
extends RefCounted
## Frontier security and pirates (Sub-spec B9, D9; M2 rules agreed 2026-10-01). Pirate units belong to no
## empire (owner PIRATES) and hunt one empire (target_owner). All randomness uses the `events` stream.
##   Monthly: own frontier systems (reach >= pirate_min_reach) with security < threshold roll
##   (threshold - security) x chance permille to spawn a raider (max per hunted empire); raiders move toward the
##   neighbouring frontier system with the most of their target's freight, may found a base, or leave.
##   Hourly: a freighter in a raider's system rolls once per passage (B9); detected = lost with its cargo.

const PIRATES := -1  # owner of pirate units
const LOSS_LOG := 50


## D9 security of a system for its owner (M2 terms: base, garrisons, station security, reach 7+ halves it).
## station_security: optional precomputed {system: sum of own station security} (see station_security_map).
static func security(state: MatchState, system_id: int, reach: Dictionary = {}, station_security: Variant = null) -> int:
	var r := Economy.rules(state.defs)
	var sys := state.galaxy.system(system_id)
	var sec := r.security_base
	for pid in sys.planet_ids:
		var c := state.colony(pid)
		if c != null and c.owner == sys.owner:
			sec += r.security_per_garrison * PlanetMods.of(c, state.defs).add("planet.garrison")
	var by_system: Dictionary = station_security if station_security != null else station_security_map(state)
	sec += int(by_system.get(system_id, 0))
	sec += int(patrol_security_map(state).get(system_id, 0))
	if sys.owner != StateIO.NONE and Economy.reach_of(state, reach, sys.owner, system_id) >= r.reach_3:
		sec = FixedMath.floor_div(sec, 2)
	return clampi(sec, 0, 100)


## {system: security from active patrols of the system's owner} (main spec 6.6; cached per tick).
static func patrol_security_map(state: MatchState) -> Dictionary:
	var scratch := state.scratch()
	if not scratch.has("patrol_security"):
		var out := {}
		var cr := state.defs.get_def(CombatRulesDef.ID) as CombatRulesDef
		if cr != null:
			for fid: int in state.fleets.ordered():
				var f: Fleet = state.fleets.get_or(fid)
				if f.mission != "patrol":
					continue
				for sys_id in f.patrol:
					if state.galaxy.system(sys_id).owner == f.owner and not out.has(sys_id):
						out[sys_id] = cr.patrol_security
		scratch["patrol_security"] = out
	return scratch["patrol_security"]


## {system: security from operational stations owned by the owner of that system}.
static func station_security_map(state: MatchState) -> Dictionary:
	var out := {}
	for sid: int in state.stations.ordered():
		var st: Station = state.stations.get_or(sid)
		if st.operational and st.owner == state.galaxy.system(st.system_id).owner:
			var v := (state.defs.get_def(StringName(st.def_id)) as StationDef).security
			if v != 0:
				out[st.system_id] = int(out.get(st.system_id, 0)) + v
	return out


## {system: true} where a raider hunting this empire sits (freighters route around them, B8 route safety).
static func raided_systems(state: MatchState, eid: int) -> Dictionary:
	var scratch := state.scratch()
	var key := "raided:%d" % eid
	if not scratch.has(key):
		var out := {}
		for uid: int in state.units.ordered():
			var u: Unit = state.units.get_or(uid)
			if (u.kind == "raider" or u.kind == "pirate_base") and u.target_owner == eid:
				out[u.system_id] = true
				for s in u.path:
					out[s] = true
		scratch[key] = out
	return scratch[key]


static func raiders_hunting(state: MatchState, eid: int) -> int:
	var n := 0
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.kind == "raider" and u.target_owner == eid:
			n += 1
	return n


static func month_tick(state: MatchState) -> void:
	var r := Economy.rules(state.defs)
	var rng := state.rng(DetRng.EVENTS)
	var reach := {}
	var traffic := {}  # empire id -> {system: freighters there or passing through}, built on first use
	# Raiders: leave, found a base, or move toward freight traffic.
	for uid: int in state.units.keys():
		var u: Unit = state.units.get_or(uid)
		if u.kind != "raider":
			continue
		if u.months_left > 0:
			u.months_left -= 1
			if u.months_left == 0:
				state.units.erase(uid)
				continue
		if not state.pirate_bases.has(u.system_id) and rng.range(0, 1000) < r.pirate_base_chance_permille:
			found_base(state, u.system_id, u.target_owner)
			u.months_left = 0  # guards its base from now on
		elif not u.is_moving() and not Battles.in_battle(state, u.id):
			_hunt(state, u, reach, traffic)
	# Bases send out raiders.
	for sys_id: int in IdMap.sort_keys(state.pirate_bases.keys()):
		state.pirate_bases[sys_id] -= 1
		if state.pirate_bases[sys_id] <= 0:
			state.pirate_bases[sys_id] = r.pirate_base_spawn_months
			var owner := state.galaxy.system(sys_id).owner
			if owner != StateIO.NONE and raiders_hunting(state, owner) < r.max_raiders_per_empire:
				spawn_raider(state, sys_id, owner)
	# Frontier systems roll (D9).
	var stations := station_security_map(state)
	for eid: int in state.empires.ordered():
		var hunting := raiders_hunting(state, eid)
		for sys_id: int in state.galaxy.systems.ordered():
			if hunting >= r.max_raiders_per_empire:
				break
			if state.galaxy.system(sys_id).owner != eid or Economy.reach_of(state, reach, eid, sys_id) < r.pirate_min_reach:
				continue
			var sec := security(state, sys_id, reach, stations)
			if sec < r.pirate_threshold and rng.range(0, 1000) < (r.pirate_threshold - sec) * r.pirate_chance_per_point_permille:
				spawn_raider(state, sys_id, eid)
				hunting += 1


## A pirate base (D9): the spawn timer, plus (M3) an immobile armed base unit that warships can destroy.
static func found_base(state: MatchState, system_id: int, target: int) -> Unit:
	state.pirate_bases[system_id] = Economy.rules(state.defs).pirate_base_spawn_months
	var cr := state.defs.get_def(CombatRulesDef.ID) as CombatRulesDef
	var design := state.defs.get_def(cr.pirate_base_design) as DesignDef if cr != null else null
	if design == null:
		return null
	var u := Unit.new()
	u.id = state.alloc_id()
	u.owner = PIRATES
	u.kind = "pirate_base"
	u.system_id = system_id
	u.body = state.galaxy.system(system_id).planet_ids[0] if not state.galaxy.system(system_id).planet_ids.is_empty() else StateIO.NONE
	u.target_owner = target
	u.hull_id = String(design.hull)
	u.components.assign(Array(design.components).map(func(c: StringName) -> String: return String(c)))
	Fleets.arm(state, u)
	state.units.put(u.id, u)
	return u


## Called when a base unit is destroyed: the base is gone once no base unit is left in its system.
static func base_destroyed(state: MatchState, system_id: int) -> void:
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.kind == "pirate_base" and u.system_id == system_id:
			return
	state.pirate_bases.erase(system_id)


static func spawn_raider(state: MatchState, system_id: int, target: int) -> Unit:
	var u := Unit.new()
	u.id = state.alloc_id()
	u.owner = PIRATES
	u.kind = "raider"
	u.system_id = system_id
	u.speed = CmdDebugSpawnScout.SCOUT_SPEED
	u.target_owner = target
	u.months_left = Economy.rules(state.defs).raider_months
	var cr := state.defs.get_def(CombatRulesDef.ID) as CombatRulesDef
	var design := state.defs.get_def(cr.pirate_raider_design) as DesignDef if cr != null else null
	if design != null:  # M3: raiders fly the pirate raider design and fight
		u.hull_id = String(design.hull)
		u.components.assign(Array(design.components).map(func(c: StringName) -> String: return String(c)))
		Fleets.arm(state, u)
	state.units.put(u.id, u)
	return u


## Move one lane toward the frontier neighbour with the most of the target's freighters (in it or passing).
static func _hunt(state: MatchState, u: Unit, reach: Dictionary, traffic: Dictionary = {}) -> void:
	var r := Economy.rules(state.defs)
	if not traffic.has(u.target_owner):
		traffic[u.target_owner] = _traffic_map(state, u.target_owner)
	var by_system: Dictionary = traffic[u.target_owner]
	var best := u.system_id
	var best_traffic := int(by_system.get(u.system_id, 0))
	for lid in state.galaxy.system(u.system_id).lane_ids:
		var nxt := state.galaxy.lane(lid).other_end(u.system_id)
		if Economy.reach_of(state, reach, u.target_owner, nxt) < r.pirate_min_reach:
			continue  # raiders stay on the frontier
		var t := int(by_system.get(nxt, 0))
		if t > best_traffic or (t == best_traffic and best != u.system_id and nxt < best):
			best = nxt
			best_traffic = t
	if best != u.system_id:
		u.path = [best] as Array[int]
		u.progress = 0


## {system: number of the empire's freighters in it or with it on their path} (each freighter counts once
## per system).
static func _traffic_map(state: MatchState, eid: int) -> Dictionary:
	var out := {}
	for uid: int in state.units.ordered():
		var f: Unit = state.units.get_or(uid)
		if f.owner != eid or f.kind != "freighter":
			continue
		var seen := {f.system_id: true}
		for sys_id in f.path:
			seen[sys_id] = true
		for sys_id: int in seen:
			out[sys_id] = int(out.get(sys_id, 0)) + 1
	return out


## Hourly: passage rolls for freighters sharing a system with a raider hunting their owner (B9).
static func tick(state: MatchState) -> void:
	var hunted := {}  # "system:owner" -> true: raiders hunting that owner, or (M3) its enemies' warships at war
	var enemies := {}  # empire -> [empires at war with it]
	for key: String in state.wars:
		var a := int(key.get_slice(":", 0))
		var b := int(key.get_slice(":", 1))
		enemies[a] = enemies.get(a, []) + [b]
		enemies[b] = enemies.get(b, []) + [a]
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.is_moving():
			continue
		if u.kind == "raider":
			hunted["%d:%d" % [u.system_id, u.target_owner]] = true
		elif u.kind == "warship":
			for other: int in enemies.get(u.owner, []):
				hunted["%d:%d" % [u.system_id, other]] = true  # fleets at war raid convoys (main spec 6.6)
	if hunted.is_empty():
		return
	var r := Economy.rules(state.defs)
	var cr := state.defs.get_def(CombatRulesDef.ID) as CombatRulesDef
	var chance := FixedMath.floor_div(r.raider_sensor * 1000, r.raider_sensor + 50)
	for uid: int in state.units.keys():
		var f: Unit = state.units.get_or(uid)
		if f.kind != "freighter" or f.raid_checked == f.system_id:
			continue
		f.raid_checked = f.system_id
		if not hunted.has("%d:%d" % [f.system_id, f.owner]):
			continue
		var odds := chance
		var escort := Fleets.escort_for(state, f.home) if cr != null and f.home != StateIO.NONE else null
		if escort != null:
			odds = FixedMath.mul_permille(odds, cr.escort_raid)  # escorted: the raiders must get past the escort
			Fleets.hunt(state, escort, f.system_id)
		if state.rng(DetRng.EVENTS).range(0, 1000) < odds:
			_lose(state, f)


static func _lose(state: MatchState, f: Unit) -> void:
	var e := state.empire(f.owner)
	e.losses.append({"tick": state.tick, "unit": f.id, "system": f.system_id, "hull": f.hull_id, "cargo": f.cargo.duplicate()})
	if e.losses.size() > LOSS_LOG:
		e.losses.remove_at(0)
	state.units.erase(f.id)
