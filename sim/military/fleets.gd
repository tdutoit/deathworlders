class_name Fleets
extends RefCounted
## Fleet membership, the naval hierarchy and fleet movement (main spec 7.1, 7.6; owner decisions
## 2026-10-01): ships auto-group into squadrons of one class (capital classes first), squadrons into task
## forces, within combat_rules limits. A fleet's ships share one route and move at the fleet's speed: the
## slowest ship's hull speed in lane units per day, halved while any ship is out of fuel.

const CLASS_ORDER: Array[String] = ["battleship", "battlecruiser", "carrier", "cruiser", "destroyer", "assault",
	"frigate", "corvette"]


static func rules(state: MatchState) -> CombatRulesDef:
	return state.defs.get_def(CombatRulesDef.ID)


## Rebuilds the hierarchy from the fleet's ships: by class (CLASS_ORDER, then class name), then ship ID.
static func regroup(state: MatchState, f: Fleet) -> void:
	var r := rules(state)
	var ids := f.ships()
	ids.sort_custom(func(a: int, b: int) -> bool:
		var ka := _class_key(state, a)
		var kb := _class_key(state, b)
		return ka < kb or (ka == kb and a < b))
	var squads := []
	var last := ""
	for sid in ids:
		var key := _class_key(state, sid)
		if squads.is_empty() or key != last or (squads[-1] as Array).size() >= r.squadron_max:
			squads.append([] as Array[int])
		(squads[-1] as Array).append(sid)
		last = key
	f.task_forces = []
	for sq: Array in squads:
		if f.task_forces.is_empty() or (f.task_forces[-1] as Array).size() >= r.task_force_squadrons:
			f.task_forces.append([])
		(f.task_forces[-1] as Array).append(sq)


static func _class_key(state: MatchState, ship_id: int) -> String:
	var u: Unit = state.units.get_or(ship_id)
	var h := state.defs.get_def(StringName(u.hull_id)) as HullDef if u != null else null
	var cls := String(h.hull_class) if h != null else ""
	var rank := CLASS_ORDER.find(cls)
	return "%02d:%s" % [rank if rank >= 0 else CLASS_ORDER.size(), cls]


## Task forces these ships would need, auto-grouped (for the fleet size limit).
static func task_forces_needed(state: MatchState, ship_ids: Array) -> int:
	var probe := Fleet.new()
	probe.task_forces = [[ship_ids.duplicate()]]
	regroup(state, probe)
	return probe.task_forces.size()


static func fits(state: MatchState, ship_ids: Array) -> bool:
	return task_forces_needed(state, ship_ids) <= rules(state).fleet_task_forces


static func create(state: MatchState, owner: int, ship_ids: Array, name := "", reserve := false) -> Fleet:
	var f := Fleet.new()
	f.id = state.alloc_id()
	f.owner = owner
	f.name = name
	f.reserve = reserve
	state.fleets.put(f.id, f)
	add_ships(state, f, ship_ids)
	return f


## Moves ships into a fleet (leaving their old fleets) and regroups it.
static func add_ships(state: MatchState, f: Fleet, ship_ids: Array) -> void:
	var all := f.ships()
	for sid: int in ship_ids:
		var u: Unit = state.units.get_or(sid)
		if u.fleet != StateIO.NONE and u.fleet != f.id:
			remove_ship(state, u)
		u.fleet = f.id
		if not sid in all:
			all.append(sid)
	f.task_forces = [[all]]
	regroup(state, f)


## Takes a ship out of its fleet, keeping the rest of the hierarchy (empty squadrons and task forces go);
## an emptied fleet is removed.
static func remove_ship(state: MatchState, u: Unit) -> void:
	var f: Fleet = state.fleets.get_or(u.fleet)
	u.fleet = StateIO.NONE
	if f == null:
		return
	var tfs := []
	for tf: Array in f.task_forces:
		var squads := []
		for sq: Array in tf:
			var kept := sq.filter(func(x: int) -> bool: return x != u.id)
			if not kept.is_empty():
				squads.append(kept)
		if not squads.is_empty():
			tfs.append(squads)
	f.task_forces = tfs
	if tfs.is_empty():
		state.fleets.erase(f.id)


## The fleet's lead ship (its position and route stand for the fleet), or null.
static func lead(state: MatchState, f: Fleet) -> Unit:
	var ids := f.ships()
	return state.units.get_or(ids[0]) if not ids.is_empty() else null


static func is_moving(state: MatchState, f: Fleet) -> bool:
	var u := lead(state, f)
	return u != null and u.is_moving()


## Lane speed in milli-lane-units per hour: slowest hull speed (lane units/day), halved if any ship is out of
## fuel. Cached per tick.
static func move_speed(state: MatchState, fleet_id: int) -> int:
	var scratch := state.scratch()
	var key := "fleet_speed:%d" % fleet_id
	if not scratch.has(key):
		var f: Fleet = state.fleets.get_or(fleet_id)
		var slowest := -1
		var out_of_fuel := false
		if f != null:
			for sid in f.ships():
				var u: Unit = state.units.get_or(sid)
				var h := state.defs.get_def(StringName(u.hull_id)) as HullDef
				var sp := h.speed if h != null else 0
				slowest = sp if slowest < 0 else mini(slowest, sp)
				out_of_fuel = out_of_fuel or u.out_of_fuel
		var per_hour := FixedMath.floor_div(maxi(slowest, 0) * Movement.MILLI, Calendar.HOURS_PER_DAY)
		scratch[key] = FixedMath.floor_div(per_hour, 2) if out_of_fuel else per_hour
	return scratch[key]


## Hourly fleet missions (main spec 6.6): patrols cycle through their systems, waiting patrol_wait_hours in
## each; escorts are moved by the raid rolls (Pirates.tick). Fleets in battle or under way are left alone.
static func mission_tick(state: MatchState) -> void:
	var r := rules(state)
	if r == null:
		return
	for fid: int in state.fleets.keys():
		var f: Fleet = state.fleets.get_or(fid)
		if f == null or f.mission != "patrol" or f.patrol.is_empty():
			continue
		var l := lead(state, f)
		if l == null or l.is_moving() or Battles.in_battle(state, l.id):
			continue
		f.patrol_index = posmod(f.patrol_index, f.patrol.size())
		if l.system_id == f.patrol[f.patrol_index]:
			if f.patrol_wait < r.patrol_wait_hours:
				f.patrol_wait += 1
				continue
			f.patrol_index = posmod(f.patrol_index + 1, f.patrol.size())
			f.patrol_wait = 0
		var route := Pathfinder.route(state.galaxy, l.system_id, f.patrol[f.patrol_index])
		_route_keep_mission(state, f, route)


## The fleet's escort covers a freighter's hub: escort mission, idle or under way, within hub range.
static func escort_for(state: MatchState, hub: int) -> Fleet:
	var scratch := state.scratch()
	if not scratch.has("escorts"):
		var m := {}
		for fid: int in state.fleets.ordered():
			var f: Fleet = state.fleets.get_or(fid)
			if f.mission == "escort" and not m.has(f.escort_hub):
				m[f.escort_hub] = f.id
		scratch["escorts"] = m
	var fid: Variant = scratch["escorts"].get(hub)
	if fid == null:
		return null
	var f: Fleet = state.fleets.get_or(fid)
	var l := lead(state, f) if f != null else null
	if l == null or Battles.in_battle(state, l.id) or Holders.system(state, hub) == StateIO.NONE:
		return null
	var hops := int(AutoLogistics._hops_from(state, Holders.system(state, hub), {}).get(l.system_id, Sectors.FAR))
	return f if hops <= AutoLogistics.hub_range(state, hub) else null


## Sends an escort to where a raid happened (it keeps its mission).
static func hunt(state: MatchState, f: Fleet, system_id: int) -> void:
	var l := lead(state, f)
	if l == null or l.is_moving() or l.system_id == system_id:
		return
	_route_keep_mission(state, f, Pathfinder.route(state.galaxy, l.system_id, system_id))


static func _route_keep_mission(state: MatchState, f: Fleet, route: Array[int]) -> void:
	for sid in f.ships():
		var u: Unit = state.units.get_or(sid)
		u.path = route.duplicate()
		if u.path.is_empty():
			u.progress = 0
	f.reserve = false


## Gives every ship of the fleet the same route (they share a position, so they stay together).
static func set_route(state: MatchState, f: Fleet, route: Array[int]) -> void:
	for sid in f.ships():
		var u: Unit = state.units.get_or(sid)
		u.path = route.duplicate()
		if u.path.is_empty():
			u.progress = 0
	f.reserve = false  # a fleet that leaves stops collecting new ships
	f.mission = ""  # a manual move ends any escort or patrol


## A just-launched warship: full combat state from its design, then the system's reserve fleet (or a new one).
static func commission(state: MatchState, u: Unit) -> void:
	arm(state, u)
	join_reserve(state, u)


## Full combat state from the unit's hull and components.
static func arm(state: MatchState, u: Unit) -> void:
	var st := ShipStats.of(state.defs, u.hull_id, u.components)
	u.hp = st.hull
	u.armor = st.armor
	u.shield = st.shield
	u.ammo = st.ammo
	u.crew = st.crew
	u.marines = st.marines


## The system's reserve fleet takes the ship (or a new reserve fleet is started there).
static func join_reserve(state: MatchState, u: Unit) -> void:
	for fid: int in state.fleets.ordered():
		var f: Fleet = state.fleets.get_or(fid)
		var l := lead(state, f)
		if f.owner == u.owner and f.reserve and l != null and l.system_id == u.system_id and not l.is_moving() \
				and fits(state, f.ships() + [u.id]):
			add_ships(state, f, [u.id])
			return
	create(state, u.owner, [u.id], "", true)
