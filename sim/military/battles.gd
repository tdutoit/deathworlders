class_name Battles
extends RefCounted
## Space battles (Sub-spec A3–A12; owner decisions 2026-10-01). Hourly, after movement:
##   1. Battles start where hostile armed combatants (warships, raiders, pirate bases, defence stations) sit
##      in one system, not moving; more of the same owners in that system join as reinforcements.
##   2. Each battle fights one round (A4): range step every 3rd round (A5), fleet PD pools (A8), every shot
##      against start-of-round state (targeting A6, hit A7, interception A8), damage applied in target-ID
##      order (A9), losses, shield regen, boarding at Close (A11), morale (A10), retreat and disengage (A10),
##      end check (A12).
## Iteration is by ascending ID; each battle has its own RNG seeded match_seed ^ battle ID. All numbers come
## from combat_rules and weapon_family Defs. No terrain, intel, commanders or species traits in M3.

const BANDS := {"standoff": 0, "line": 1, "close": 2, "boarding": 2}
const SIZE_RANK := {&"S": 0, &"M": 1, &"L": 2, &"XL": 3}
const COMBATANT_KINDS: Array[String] = ["warship", "raider", "pirate_base"]
const RECENT_DEFEAT_DAYS := 30


static func rules(state: MatchState) -> CombatRulesDef:
	return state.defs.get_def(CombatRulesDef.ID)


# --- hostility (M3: pirates are hostile to all; empires only at war, WP7) ---

static func hostile(state: MatchState, a: int, b: int) -> bool:
	if a == b:
		return false
	if a == Pirates.PIRATES or b == Pirates.PIRATES:
		return true
	return state.wars.has(war_key(a, b))


static func war_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


# --- combatants ---

static func entity(state: MatchState, id: int) -> Object:
	var u: Unit = state.units.get_or(id)
	return u if u != null else state.stations.get_or(id)


static func is_armed_station(state: MatchState, s: Station) -> bool:
	return s.hp > 0 and s.operational and (state.defs.get_def(StringName(s.def_id)) as StationDef).function == &"defence"


## [hull ID, component IDs] of a unit or a defence station.
static func loadout(state: MatchState, id: int) -> Array:
	var u: Unit = state.units.get_or(id)
	if u != null:
		return [u.hull_id, u.components]
	var s: Station = state.stations.get_or(id)
	var d := state.defs.get_def((state.defs.get_def(StringName(s.def_id)) as StationDef).design) as DesignDef
	return [String(d.hull), Array(d.components).map(func(c: StringName) -> String: return String(c))]


static func stats(state: MatchState, id: int) -> ShipStats:
	var l := loadout(state, id)
	var e: Object = entity(state, id)
	return ShipStats.cached(state.defs, l[0], l[1], SpeciesTraits.source_of(state, int(e.get("owner"))) if e != null else "")


## Battle value in credits (A1 cost): resources at their base value.
static func cost_of(state: MatchState, id: int) -> int:
	var l := loadout(state, id)
	var total := 0
	var c := ShipStats.cost(state.defs, l[0], l[1])
	for res: String in c:
		var rd := state.defs.get_def(StringName(res)) as ResourceDef
		total += int(c[res]) * (rd.base_value if rd else 1000)
	return FixedMath.floor_div(total, 1000)


## Full combat state for a defence station that just became operational.
static func arm_station(state: MatchState, s: Station) -> void:
	var st := stats(state, s.id)
	s.hp = st.hull
	s.armor = st.armor
	s.shield = st.shield
	s.ammo = st.ammo
	s.crew = st.crew


## {system: {owner: true}} of stationary armed combatants (cached per tick); for interdiction.
static func presence(state: MatchState) -> Dictionary:
	var scratch := state.scratch()
	if not scratch.has("combat_presence"):
		var out := {}
		for uid: int in state.units.ordered():
			var u: Unit = state.units.get_or(uid)
			if u.kind in COMBATANT_KINDS and not u.is_moving():
				if not out.has(u.system_id):
					out[u.system_id] = {}
				out[u.system_id][u.owner] = true
		for sid: int in state.stations.ordered():
			var s: Station = state.stations.get_or(sid)
			if is_armed_station(state, s):
				if not out.has(s.system_id):
					out[s.system_id] = {}
				out[s.system_id][s.owner] = true
		scratch["combat_presence"] = out
	return scratch["combat_presence"]


## True if an owner hostile to `owner` has stationary armed combatants in the system (interdiction).
static func hostile_present(state: MatchState, system_id: int, owner: int) -> bool:
	for other: int in presence(state).get(system_id, {}):
		if hostile(state, owner, other):
			return true
	return false


## Battle a combatant is fighting in, or null (cached per tick).
static func battle_of(state: MatchState, id: int) -> Battle:
	var scratch := state.scratch()
	if not scratch.has("in_battle"):
		var m := {}
		for bid: int in state.battles.ordered():
			var b: Battle = state.battles.get_or(bid)
			for cid in b.active():
				m[cid] = bid
		scratch["in_battle"] = m
	var bid: Variant = scratch["in_battle"].get(id)
	return state.battles.get_or(bid) if bid != null else null


static func in_battle(state: MatchState, id: int) -> bool:
	return battle_of(state, id) != null


# --- hour tick ---

static func tick(state: MatchState) -> void:
	if state.defs == null or rules(state) == null:
		return
	_start_battles(state)
	for bid: int in state.battles.keys():
		var b: Battle = state.battles.get_or(bid)
		if _round(state, b):
			_finish(state, b)
	state.scratch().erase("in_battle")
	state.scratch().erase("combat_presence")


static func _start_battles(state: MatchState) -> void:
	# Only systems where hostile owners both have stationary combatants can start or join a battle
	# (presence is cached per tick and usually already built by movement's interdiction checks).
	var contested := {}
	var pres := presence(state)
	for system_id: int in pres:
		var owners: Array = IdMap.sort_keys(pres[system_id].keys())
		if owners.size() > 1 and not _hostile_pair(state, owners).is_empty():
			contested[system_id] = true
	for bid: int in state.battles.ordered():  # reinforcements join battles under way
		contested[(state.battles.get_or(bid) as Battle).system_id] = true
	if contested.is_empty():
		return
	var by_system := {}  # system -> [combatant ids not yet in a battle], ascending
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if contested.has(u.system_id) and u.kind in COMBATANT_KINDS and not u.is_moving() and not in_battle(state, uid):
			if not by_system.has(u.system_id):
				by_system[u.system_id] = []
			by_system[u.system_id].append(uid)
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if contested.has(s.system_id) and is_armed_station(state, s) and not in_battle(state, sid):
			if not by_system.has(s.system_id):
				by_system[s.system_id] = []
			by_system[s.system_id].append(sid)
	for system_id: int in IdMap.sort_keys(by_system.keys()):
		var ids: Array = by_system[system_id]
		ids.sort()
		var b := _battle_at(state, system_id)
		if b == null:
			var owners := {}
			for cid: int in ids:
				owners[_owner(state, cid)] = true
			var pair := _hostile_pair(state, IdMap.sort_keys(owners.keys()))
			if pair.is_empty():
				continue
			b = _create(state, system_id, pair)
		for cid: int in ids:
			var side := _assign_side(state, b, _owner(state, cid))
			if side >= 0:
				_join(state, b, cid, side)
	state.scratch().erase("in_battle")


static func _battle_at(state: MatchState, system_id: int) -> Battle:
	for bid: int in state.battles.ordered():
		var b: Battle = state.battles.get_or(bid)
		if b.system_id == system_id:
			return b
	return null


## The side this owner fights on: its existing side, or the side whose enemies it is hostile to while hostile
## to nobody on that side (allies and co-belligerents join; owner decision 2026-10-02), else -1 (it waits).
static func _assign_side(state: MatchState, b: Battle, owner: int) -> int:
	var s := b.side_of_owner(owner)
	if s >= 0:
		return s
	for side in 2:
		var friends: Array = b.sides[side]
		var foes: Array = b.sides[1 - side]
		if foes.any(func(o: int) -> bool: return hostile(state, owner, o)) \
				and not friends.any(func(o: int) -> bool: return hostile(state, owner, o)):
			friends.append(owner)
			return side
	return -1


## True while some owner on one side is still hostile to some owner on the other.
static func _sides_hostile(state: MatchState, b: Battle) -> bool:
	for a: int in b.sides[0]:
		for o: int in b.sides[1]:
			if hostile(state, a, o):
				return true
	return false


static func _hostile_pair(state: MatchState, owners: Array) -> Array[int]:
	for i in owners.size():
		for j in range(i + 1, owners.size()):
			if hostile(state, owners[i], owners[j]):
				return [owners[i], owners[j]] as Array[int]
	return []


static func _owner(state: MatchState, id: int) -> int:
	return (entity(state, id) as Object).get("owner")


static func _create(state: MatchState, system_id: int, owners: Array[int]) -> Battle:
	var b := Battle.new()
	b.id = state.alloc_id()
	b.system_id = system_id
	b.start_tick = state.tick
	b.owners = owners
	b.sides = [[owners[0]] as Array[int], [owners[1]] as Array[int]]
	b.band = 0  # A3: battles open at Long range (no nebulae in M5)
	b.rng = DetRng.from_seed(state.match_seed ^ b.id, DetRng.COMBAT).get_state()
	b.log = {"strength": [], "bands": [], "lost": [], "captured": [], "retreated": [], "events": [], "start_cost": [0, 0],
		"lost_cost": [0, 0], "captured_cost": [0, 0], "dmg": {}, "kills": {}, "names": {},
		"family": [{}, {}],  # per side: family ID -> [shots, hits, intercepted, hull damage]
		"ambush": Intel.ambush_side(state, owners)}  # A3 step 3 (M5): this side fires alone in round 1, -1 = none
	state.battles.put(b.id, b)
	return b


## Adds a combatant to its side: its fleet's task force, or its owner's group (ships outside fleets,
## stations, captured ships).
static func _join(state: MatchState, b: Battle, id: int, side: int) -> void:
	var r := rules(state)
	var u: Unit = state.units.get_or(id)
	var key := ""
	var fleet: Fleet = null
	if u != null and u.fleet != StateIO.NONE:
		fleet = state.fleets.get_or(u.fleet)
		for i in fleet.task_forces.size():
			for sq: Array in fleet.task_forces[i]:
				if id in sq:
					key = "f:%d:%d" % [fleet.id, i]
	var owner := _owner(state, id)
	if key == "":
		key = ("o:%d" % owner) if u != null else ("s:%d" % owner)
	var form: Dictionary = {}
	for f: Dictionary in b.formations:
		if f["key"] == key and not f["left"]:
			form = f
	var st := stats(state, id)
	var cost := cost_of(state, id)
	if form.is_empty():
		var morale := r.morale_start
		if u != null and u.unsupplied_days > 0:
			morale += r.morale_out_of_supply
		if fleet != null and fleet.defeated_tick > 0 and state.tick - fleet.defeated_tick <= RECENT_DEFEAT_DAYS * Calendar.HOURS_PER_DAY:
			morale += r.morale_recent_defeat
		form = {"key": key, "side": side, "owner": owner, "members": [] as Array[int], "morale": morale, "hull_start": 0,
			"cost_start": 0, "disengage": -1, "left": false,
			"retreat_at": fleet.retreat_at if fleet != null else (0 if u == null else 500),
			"range_pref": fleet.range_pref if fleet != null else "line",
			"target": fleet.target_priority if fleet != null else "largest"}
		b.formations.append(form)
	(form["members"] as Array).append(id)
	form["hull_start"] = int(form["hull_start"]) + st.hull
	form["cost_start"] = int(form["cost_start"]) + cost
	b.log["start_cost"][side] += cost
	var design_name := ""
	if u != null and state.designs.has(u.design):
		design_name = (state.designs.get_or(u.design) as ShipDesign).name
	b.log["names"][str(id)] = [owner, String(st.hull_class), design_name]


# --- one round (A4). Returns true when the battle is over. ---

static func _round(state: MatchState, b: Battle) -> bool:
	var r := rules(state)
	var rng := DetRng.new(1, 2, 3, 4)
	rng.set_state(b.rng)
	for f: Dictionary in b.formations:  # combatants that vanished since the last round (e.g. a raider's time ran out)
		f["members"] = (f["members"] as Array).filter(func(cid: int) -> bool: return entity(state, cid) != null)
	if b.active(0).is_empty() or b.active(1).is_empty():
		return true
	if not _sides_hostile(state, b):
		b.log["truce"] = 1  # peace was made: the battle ends where it stands
		return true
	b.round += 1
	# 1. Range step every 3rd round (A5).
	if b.round % r.range_step_rounds == 0:
		_range_step(state, b, rng)
	# 2. Point-defence pools (A8).
	var pd := [0, 0]
	for side in 2:
		for cid in b.active(side):
			pd[side] += stats(state, cid).pd
	# 3. Fire, against start-of-round state.
	var queue := []  # [target, damage, family ID, penetration, shooter, order]
	var lists := {}  # "side:priority" -> ordered candidate IDs
	var disengaging := _disengaging(b)
	var last_stand := {}  # combatants of formations in a Last Stand (A10)
	for f: Dictionary in b.formations:
		if int(f.get("last_stand", 0)) > 0:
			for m: int in f["members"]:
				last_stand[m] = true
	var ambushed := 1 - int(b.log.get("ambush", -1)) if int(b.log.get("ambush", -1)) >= 0 and b.round == 1 else -1
	for cid in b.active():
		if disengaging.has(cid):
			continue
		var side := b.side_of(cid)
		if side == ambushed:
			continue  # A3: caught by an ambush, holds fire in the opening round
		var shooter: Object = entity(state, cid)
		var st := stats(state, cid)
		var bonus := _accuracy_bonus(state, b, cid, shooter, st, r)
		var priority := _formation_of(b, cid)["target"] as String
		for w in st.weapons:
			var fam := state.defs.get_def(w.family) as WeaponFamilyDef
			for shot in w.shots:
				if w.ammo_per_shot > 0:
					if int(shooter.get("ammo")) < w.ammo_per_shot:
						break
					shooter.set("ammo", int(shooter.get("ammo")) - w.ammo_per_shot)
				var target := _pick_target(state, b, 1 - side, priority, w, lists, rng, r)
				if target == 0:
					break
				var fstats: Dictionary = b.log["family"][side]
				var fk := String(w.family)
				if not fstats.has(fk):
					fstats[fk] = [0, 0, 0, 0]
				fstats[fk][0] += 1
				if fam != null and fam.interceptable and pd[1 - side] > 0:
					pd[1 - side] -= 1
					if rng.roll_permille() < r.pd_intercept:
						fstats[fk][2] += 1
						continue
				var tst := stats(state, target)
				var hit := int(w.accuracy[b.band]) + w.tracking + bonus - tst.evasion + int(st.accuracy.get(w.family, 0))
				if fam != null and fam.ecm_affected:
					hit -= (r.ecm_missile_penalty + tst.ecm_strength) * tst.ecm
				if disengaging.has(target):
					hit += r.disengage_incoming_accuracy + SpeciesTraits.empire_add(state, int(shooter.get("owner")), "empire.pursuit_accuracy")
				hit = clampi(hit, r.hit_min, r.hit_max)
				if rng.roll_permille() >= hit:
					continue
				fstats[fk][1] += 1
				var dmg := FixedMath.floor_div(w.damage * rng.range(r.variance_min, r.variance_max), 1000)
				dmg = FixedMath.mul_permille(dmg, 1000 + int(st.damage.get(w.family, 0)) + (r.last_stand_damage if last_stand.has(cid) else 0))
				queue.append([target, dmg, w.family, w.penetration, cid, queue.size()])
	# 4. Apply damage in target-ID order (A4 step 4, A9).
	queue.sort_custom(func(a: Array, c: Array) -> bool: return a[0] < c[0] or (a[0] == c[0] and a[5] < c[5]))
	var hull_lost := {}  # formation key -> hull lost this round
	var last_hit := {}  # target -> shooter
	for q: Array in queue:
		var t: Object = entity(state, q[0])
		if t == null or int(t.get("hp")) <= 0:
			continue
		var lost := _damage(state, t, q[1], state.defs.get_def(q[2]) as WeaponFamilyDef, q[3], r)
		var key := _formation_of(b, q[0])["key"] as String
		hull_lost[key] = int(hull_lost.get(key, 0)) + lost
		b.log["dmg"][str(q[4])] = int(b.log["dmg"].get(str(q[4]), 0)) + lost
		var side := b.side_of(q[4])
		if side >= 0:
			var fk := String(q[2])
			b.log["family"][side][fk][3] += lost
		last_hit[q[0]] = q[4]
	# 5. Losses.
	var capital_lost := {}  # formation key -> capital ships lost this round
	for cid in b.active():
		var e: Object = entity(state, cid)
		if int(e.get("hp")) > 0:
			continue
		var form := _formation_of(b, cid)
		var side: int = form["side"]
		var st := stats(state, cid)
		var cost := cost_of(state, cid)
		b.log["lost"].append([side, cid, String(st.hull_class), cost, b.round])
		b.log["lost_cost"][side] += cost
		if last_hit.has(cid):
			var k := str(last_hit[cid])
			b.log["kills"][k] = int(b.log["kills"].get(k, 0)) + 1
		if not st.hull_class in r.escort_classes:
			capital_lost[form["key"]] = int(capital_lost.get(form["key"], 0)) + 1
		(form["members"] as Array).erase(cid)
		_destroy(state, cid)
	# 6. Shield regen.
	for cid in b.active():
		var e: Object = entity(state, cid)
		var st := stats(state, cid)
		e.set("shield", mini(st.shield, int(e.get("shield")) + FixedMath.mul_permille(st.shield, st.shield_regen)))
	# 7. Boarding at Close range (A11).
	if b.band == 2:
		_boarding(state, b, rng, r, disengaging)
	# 8-9. Morale, retreat and disengage (A10).
	_morale_and_retreat(state, b, rng, r, hull_lost, capital_lost)
	# Strength over time for the report.
	var strength := [0, 0]
	for side in 2:
		for cid in b.active(side):
			strength[side] += int(entity(state, cid).get("hp"))
	b.log["strength"].append(strength)
	b.log["bands"].append(b.band)  # range phase per round, for the report chart
	b.rng = rng.get_state()
	# 10. End check (A12).
	return b.active(0).is_empty() or b.active(1).is_empty() or b.round >= r.round_cap


static func _range_step(state: MatchState, b: Battle, rng: DetRng) -> void:
	var prefs := [_side_pref(b, 0), _side_pref(b, 1)]
	var target: int = prefs[0]
	if prefs[0] != prefs[1]:
		var speeds := [_slowest(state, b, 0), _slowest(state, b, 1)]
		var p_a := 500 if speeds[0] + speeds[1] == 0 else FixedMath.floor_div(speeds[0] * 1000, speeds[0] + speeds[1])
		target = prefs[0] if rng.roll_permille() < p_a else prefs[1]
	b.band += signi(target - b.band)


## A side's preferred band: its costliest formation's doctrine (stations and pirates: Line).
static func _side_pref(b: Battle, side: int) -> int:
	var best: Dictionary = {}
	for f: Dictionary in b.formations:
		if not f["left"] and f["side"] == side and (best.is_empty() or int(f["cost_start"]) > int(best["cost_start"])):
			best = f
	return BANDS.get(best.get("range_pref", "line"), 1)


## Slowest ship speed on a side (stations don't move: they count only if nothing else is there).
static func _slowest(state: MatchState, b: Battle, side: int) -> int:
	var slowest := -1
	for cid in b.active(side):
		if state.units.has(cid):
			var sp := stats(state, cid).speed
			slowest = sp if slowest < 0 else mini(slowest, sp)
	return maxi(slowest, 0)


static func _formation_of(b: Battle, id: int) -> Dictionary:
	for f: Dictionary in b.formations:
		if not f["left"] and id in f["members"]:
			return f
	return {}


static func _disengaging(b: Battle) -> Dictionary:
	var out := {}
	for f: Dictionary in b.formations:
		if not f["left"] and int(f["disengage"]) >= 0:
			for m: int in f["members"]:
				out[m] = true
	return out


## A7/A13 shooter bonuses: veterancy, crippled, out of supply, the system owner's sensor net.
static func _accuracy_bonus(state: MatchState, b: Battle, id: int, e: Object, st: ShipStats, r: CombatRulesDef) -> int:
	var bonus := 0
	var u: Unit = state.units.get_or(id)
	if u != null:
		bonus += int(r.veterancy_accuracy.get(veterancy(r, u.xp), 0))
		if u.unsupplied_days > 0:
			bonus += r.out_of_supply_accuracy
	if int(e.get("hp")) * 1000 < st.hull * r.crippled_hull:
		bonus += r.crippled_accuracy
	if state.galaxy.system(b.system_id).owner == int(e.get("owner")):
		bonus += r.sensor_net_accuracy
	return bonus


static func veterancy(r: CombatRulesDef, xp: int) -> StringName:
	var tier := &"green"
	for t: String in CombatRulesDef.VETERANCY:
		if xp >= int(r.veterancy_xp.get(StringName(t), 0)):
			tier = StringName(t)
	return tier


## A6: doctrine order, top N, escorts screen capital ships unless the weapon ignores screening.
static func _pick_target(state: MatchState, b: Battle, enemy_side: int, priority: String, w: ComponentDef, lists: Dictionary,
		rng: DetRng, r: CombatRulesDef) -> int:
	var key := "%d:%s" % [enemy_side, priority]
	if not lists.has(key):
		lists[key] = _ordered(state, b, enemy_side, priority, r)
	var info: Array = lists[key]  # [ordered ids, screened]
	var ids: Array = info[0].filter(func(x: int) -> bool: return int(entity(state, x).get("hp")) > 0 if entity(state, x) != null else false)
	if ids.is_empty():
		return 0
	var top := ids.slice(0, r.target_top)
	var weights := []
	var total := 0
	var screened: bool = info[1] and not &"ignores_screening" in w.tags
	for t: int in top:
		var weight := 1000
		if screened and not stats(state, t).hull_class in r.escort_classes:
			weight = r.screen_weight
		weights.append(weight)
		total += weight
	var roll := rng.range(0, total)
	for i in top.size():
		roll -= weights[i]
		if roll < 0:
			return top[i]
	return top[-1]


## [enemy IDs in doctrine order, screened?] at the start of the round.
static func _ordered(state: MatchState, b: Battle, side: int, priority: String, r: CombatRulesDef) -> Array:
	var ids := b.active(side)
	var escorts := 0
	var keyed := []
	for cid in ids:
		var st := stats(state, cid)
		var is_escort := st.hull_class in r.escort_classes
		if is_escort:
			escorts += 1
		var size := int(SIZE_RANK.get(st.size, 0))
		var first := 1
		match priority:
			"carriers":
				first = 0 if st.weapons.any(func(w: ComponentDef) -> bool: return w.slot_type == &"hangar") else 1
			"escorts":
				first = 0 if is_escort else 1
			"missiles":
				first = 0 if st.weapons.any(func(w: ComponentDef) -> bool: return String(w.family).ends_with("/missile")) else 1
		var sort_key: Array
		if priority == "weakest":
			sort_key = [int(entity(state, cid).get("hp")), cid]
		else:
			sort_key = [first, -size, -st.hull, cid]
		keyed.append([sort_key, cid])
	keyed.sort_custom(func(a: Array, c: Array) -> bool: return _less(a[0], c[0]))
	var screened := not ids.is_empty() and escorts * 1000 >= ids.size() * r.screen_escort_share
	return [keyed.map(func(k: Array) -> int: return k[1]), screened]


static func _less(a: Array, c: Array) -> bool:
	for i in a.size():
		if a[i] != c[i]:
			return a[i] < c[i]
	return false


## A9 damage pipeline on one hit. Returns hull damage done.
static func _damage(state: MatchState, t: Object, dmg: int, fam: WeaponFamilyDef, pen: int, r: CombatRulesDef) -> int:
	var shield_mult := fam.shield_mult if fam else 1000
	var armor_eff := fam.armor_eff if fam else 1000
	var shield_dmg := FixedMath.floor_div(dmg * shield_mult, 1000)
	var absorbed := mini(int(t.get("shield")), shield_dmg)
	t.set("shield", int(t.get("shield")) - absorbed)
	dmg -= FixedMath.floor_div(absorbed * 1000, shield_mult)
	if dmg <= 0:
		return 0
	var eff_armor := maxi(0, FixedMath.floor_div(int(t.get("armor")) * armor_eff, 1000) - pen)
	var hull_dmg := FixedMath.floor_div(dmg * r.armor_k, r.armor_k + eff_armor)
	t.set("armor", maxi(0, int(t.get("armor")) - FixedMath.floor_div(dmg - hull_dmg, r.ablation_divisor)))
	var hp := int(t.get("hp"))
	t.set("hp", hp - hull_dmg)
	return mini(hull_dmg, hp)


static func _destroy(state: MatchState, id: int) -> void:
	var u: Unit = state.units.get_or(id)
	if u != null:
		Fleets.remove_ship(state, u)
		state.units.erase(id)
		if u.kind == "pirate_base":
			Pirates.base_destroyed(state, u.system_id)  # warships can clear bases (M3)
	else:
		state.stations.erase(id)


## A11: ships with marines board the first crippled enemy ship (one attempt each; one boarding per target).
static func _boarding(state: MatchState, b: Battle, rng: DetRng, r: CombatRulesDef, disengaging: Dictionary) -> void:
	var boarded := {}
	for cid in b.active():
		var u: Unit = state.units.get_or(cid)
		if u == null or u.marines <= 0 or disengaging.has(cid):
			continue
		var side := b.side_of(cid)
		if side < 0:
			continue
		var target: Unit = null
		for tid in b.active(1 - side):
			var t: Unit = state.units.get_or(tid)
			if t != null and not boarded.has(tid) and t.hp * 1000 < stats(state, tid).hull * r.crippled_hull:
				target = t
				break
		if target == null:
			continue
		boarded[target.id] = true
		var chance := clampi(FixedMath.floor_div(u.marines * 1000, maxi(1, u.marines + target.crew)), r.boarding_min, r.boarding_max)
		if rng.roll_permille() < chance:
			_capture(state, b, target, side, r, int(entity(state, cid).get("owner")))
		else:
			u.marines -= FixedMath.mul_permille(u.marines, r.boarding_fail_loss)


static func _capture(state: MatchState, b: Battle, t: Unit, side: int, r: CombatRulesDef, captor: int) -> void:
	var from := _formation_of(b, t.id)
	(from["members"] as Array).erase(t.id)
	var cost := cost_of(state, t.id)
	b.log["captured"].append([1 - side, t.id, String(stats(state, t.id).hull_class), cost, b.round])
	b.log["captured_cost"][side] += cost
	b.log["lost_cost"][1 - side] += cost
	Fleets.remove_ship(state, t)
	Intel.ship_captured(state, captor, t.owner)  # M5: a captured ship reveals its builder
	t.owner = captor
	t.path.clear()
	var key := "c:%d" % t.owner
	for f: Dictionary in b.formations:
		if f["key"] == key and not f["left"]:
			(f["members"] as Array).append(t.id)
			return
	b.formations.append({"key": key, "side": side, "owner": t.owner, "members": [t.id] as Array[int], "morale": r.morale_start,
		"hull_start": stats(state, t.id).hull, "cost_start": cost, "disengage": -1, "left": false, "retreat_at": 500,
		"range_pref": "line", "target": "largest"})


## A10: morale loss per formation, retreat checks, disengage countdown and leaving.
static func _morale_and_retreat(state: MatchState, b: Battle, rng: DetRng, r: CombatRulesDef, hull_lost: Dictionary,
		capital_lost: Dictionary) -> void:
	var side_cost := [0, 0]
	for side in 2:
		for cid in b.active(side):
			side_cost[side] += cost_of(state, cid)
	for f: Dictionary in b.formations:
		if f["left"]:
			continue
		var side: int = f["side"]
		if int(f["disengage"]) >= 0:
			f["disengage"] = int(f["disengage"]) - 1
			if int(f["disengage"]) < 0:
				_leave(state, b, f, rng)
			continue
		if (f["members"] as Array).is_empty():
			f["left"] = true
			continue
		var loss := FixedMath.floor_div(int(hull_lost.get(f["key"], 0)) * 1000, maxi(1, int(f["hull_start"]))) * r.morale_loss_mult
		loss += r.morale_capital_lost * int(capital_lost.get(f["key"], 0))
		if side_cost[side] > 0 and side_cost[1 - side] * 1000 >= side_cost[side] * r.outnumbered_ratio:
			loss += r.morale_outnumbered
		loss = FixedMath.mul_permille(loss, 1000 - _morale_resist(state, f, r) - SpeciesTraits.empire_add(state, int(f["owner"]), "empire.morale_resist"))
		f["morale"] = maxi(0, int(f["morale"]) - loss)
		var outnumbered: bool = side_cost[side] > 0 and side_cost[1 - side] * 1000 >= side_cost[side] * r.outnumbered_ratio
		if int(f.get("last_stand", 0)) > 0:
			f["last_stand"] = int(f["last_stand"]) - 1
			f["morale"] = maxi(int(f["morale"]), r.last_stand_morale_floor)
		elif not f.has("last_stand") and outnumbered and int(f["morale"]) < r.last_stand_trigger_morale \
				and SpeciesTraits.empire_add(state, int(f["owner"]), "empire.last_stand") > 0:
			f["last_stand"] = r.last_stand_rounds  # once per battle (A10)
			f["morale"] = maxi(int(f["morale"]), r.last_stand_morale_floor)
			b.log["events"].append([b.round, "last_stand", side, f["key"]])
		if f["key"].begins_with("s:"):
			continue  # stations can't retreat
		var hull_now := 0
		for cid: int in f["members"]:
			hull_now += int(entity(state, cid).get("hp"))
		var losses := FixedMath.floor_div((int(f["hull_start"]) - hull_now) * 1000, maxi(1, int(f["hull_start"])))
		var retreat := int(f["retreat_at"]) > 0 and losses >= int(f["retreat_at"])
		if not retreat and int(f["morale"]) <= r.retreat_morale and int(f.get("last_stand", 0)) <= 0:  # no rout during a Last Stand
			retreat = rng.roll_permille() < 1000 - int(f["morale"]) * r.retreat_roll_mult
		if retreat:
			var pursued := _slowest(state, b, 1 - side) >= _slowest_of(state, f["members"])
			var extra := r.pursuit_rounds
			for o: int in b.sides[1 - side]:
				extra = maxi(extra, r.pursuit_rounds + SpeciesTraits.empire_add(state, o, "empire.pursuit_rounds"))
			f["disengage"] = r.disengage_rounds - 1 + (extra if pursued else 0)
			b.log["events"].append([b.round, "retreat", side, f["key"]])


static func _slowest_of(state: MatchState, ids: Array) -> int:
	var slowest := -1
	for cid: int in ids:
		var sp := stats(state, cid).speed
		slowest = sp if slowest < 0 else mini(slowest, sp)
	return maxi(slowest, 0)


## Formation morale resistance from its ships' average veterancy (A13); species traits add on top (A10).
static func _morale_resist(state: MatchState, f: Dictionary, r: CombatRulesDef) -> int:
	var members: Array = f["members"]
	if members.is_empty():
		return 0
	var xp := 0
	for cid: int in members:
		var u: Unit = state.units.get_or(cid)
		xp += u.xp if u != null else 0
	return int(r.veterancy_morale_resist.get(veterancy(r, FixedMath.floor_div(xp, members.size())), 0))


## A formation that finished disengaging leaves: a fleet task force becomes its own fleet heading home.
static func _leave(state: MatchState, b: Battle, f: Dictionary, rng: DetRng) -> void:
	f["left"] = true
	var owner: int = f["owner"]
	b.log["retreated"].append([f["side"], (f["members"] as Array).size(), b.round])
	var ships: Array[int] = []
	for cid: int in f["members"]:
		if state.units.has(cid):
			ships.append(cid)
	if ships.is_empty():
		return
	var next := retreat_step(state, owner, b.system_id, rng)
	if next == StateIO.NONE:
		return
	var route: Array[int] = [next]
	if (state.units.get_or(ships[0]) as Unit).fleet != StateIO.NONE:
		Fleets.set_route(state, Fleets.create(state, owner, ships), route)
	else:
		for cid in ships:
			(state.units.get_or(cid) as Unit).path = route.duplicate()


## The adjacent system to fall back to: toward the nearest system the owner supplies (pirates: toward a
## pirate base, else a random neighbour).
static func retreat_step(state: MatchState, owner: int, from: int, rng: DetRng) -> int:
	var neighbours: Array[int] = []
	for lid in state.galaxy.system(from).lane_ids:
		neighbours.append(state.galaxy.lane(lid).other_end(from))
	neighbours.sort()
	if neighbours.is_empty():
		return StateIO.NONE
	var goals := {}
	if owner == Pirates.PIRATES:
		goals = state.pirate_bases
	else:
		goals = Supply._coverage(state, owner)
	var best := StateIO.NONE
	var best_d := Sectors.FAR
	for n in neighbours:
		var hops := AutoLogistics._hops_from(state, n, {})
		var d := Sectors.FAR
		for g: int in goals:
			d = mini(d, int(hops.get(g, Sectors.FAR)))
		if d < best_d:
			best = n
			best_d = d
	return best if best != StateIO.NONE else neighbours[rng.range(0, neighbours.size())]


# --- end (A12) ---

static func _finish(state: MatchState, b: Battle) -> void:
	var r := rules(state)
	var loss := [0, 0]
	for side in 2:
		loss[side] = FixedMath.floor_div(int(b.log["lost_cost"][side]) * 1000, maxi(1, int(b.log["start_cost"][side])))
	var holds := [not b.active(0).is_empty(), not b.active(1).is_empty()]
	var results := [result(r, loss[0], loss[1], holds[0]), result(r, loss[1], loss[0], holds[1])]
	if b.log.has("truce"):
		results = ["truce", "truce"]
	var salvage := [0, 0]
	for side in 2:
		var other := 1 - side
		if String(results[side]).ends_with("victory") and b.owners[side] != Pirates.PIRATES:
			var destroyed := int(b.log["lost_cost"][other]) - int(b.log["captured_cost"][side])
			var captured := FixedMath.floor_div(int(b.log["captured_cost"][side]) * r.salvage * r.capture_salvage_mult, 1000)
			salvage[side] = FixedMath.floor_div(destroyed * r.salvage, 1000) + captured
			_share_salvage(state, b, side, salvage[side], captured)
	# Veterancy for survivors; defeat marks for the loser's fleets; captured ships join the captor's reserve.
	for side in 2:
		for cid in b.active(side):
			var u: Unit = state.units.get_or(cid)
			if u == null:
				continue
			u.xp += b.round * r.xp_per_round + int(b.log["kills"].get(str(cid), 0)) * r.xp_per_kill
			if String(results[side]) in ["defeat", "rout", "marginal_defeat"] and u.fleet != StateIO.NONE:
				(state.fleets.get_or(u.fleet) as Fleet).defeated_tick = state.tick
			if u.fleet == StateIO.NONE and u.kind == "warship":
				Fleets.join_reserve(state, u)
	var rep := BattleReport.new()
	rep.id = state.alloc_id()
	rep.data = b.log.duplicate(true)
	rep.data["system"] = b.system_id
	rep.data["start_tick"] = b.start_tick
	rep.data["end_tick"] = state.tick
	rep.data["rounds"] = b.round
	rep.data["owners"] = Array(b.owners)
	rep.data["sides"] = [Array(b.sides[0]), Array(b.sides[1])]
	rep.data["results"] = results
	rep.data["salvage"] = salvage
	state.reports.put(rep.id, rep)
	while r.report_keep > 0 and state.reports.size() > r.report_keep:
		state.reports.erase(state.reports.ordered()[0])  # oldest first (owner 2026-10-03)
	state.battles.erase(b.id)
	Wars.battle_resolved(state, b)  # M4: war score and exhaustion
	Intel.battle_fought(state, b)  # M5: intel from fighting
	SignatureMechanics.battle_resolved(state, rep)


## Salvage to each empire on the winning side by its share of the hull damage the side dealt (coalitions,
## owner decision 2026-10-02); Improvisers scale each owner's own share.
static func _share_salvage(state: MatchState, b: Battle, side: int, total: int, captured := 0) -> void:
	var loser := SpeciesTraits.species_name(state, b.owners[1 - side])  # M5: fragments of the losing lead's species
	var dmg := {}  # owner -> damage
	var side_dmg := 0
	for cid: String in IdMap.sort_keys(b.log["dmg"].keys()):
		var n: Variant = b.log["names"].get(cid)
		if n == null or not (int(n[0]) in (b.sides[side] as Array)):
			continue
		dmg[int(n[0])] = int(dmg.get(int(n[0]), 0)) + int(b.log["dmg"][cid])
		side_dmg += int(b.log["dmg"][cid])
	for owner: int in b.sides[side]:
		var e := state.empire(owner) if owner >= 0 else null
		if e == null:
			continue
		var share := FixedMath.floor_div(total * int(dmg.get(owner, 0)), side_dmg) if side_dmg > 0 else (total if owner == b.owners[side] else 0)
		var got := FixedMath.mul_permille(share, 1000 + SpeciesTraits.empire_permille(state, owner, "empire.salvage"))  # Improvisers
		var cap_share := FixedMath.floor_div(captured * int(dmg.get(owner, 0)), side_dmg) if side_dmg > 0 else (captured if owner == b.owners[side] else 0)
		got += FixedMath.mul_permille(cap_share, SpeciesTraits.empire_permille(state, owner, "empire.captured_fragments"))  # Captured Tech Study
		if loser != "" and loser != e.species:
			ReverseEngineering.add_fragments(state, owner, loser, got)
		else:
			e.tech_fragments += got  # pirates or own species: counted, nothing to reverse-engineer


## A12 result for a side from both sides' cost-weighted loss shares (permille).
static func result(r: CombatRulesDef, own: int, enemy: int, holds_field: bool) -> String:
	if enemy >= r.decisive_enemy_loss and own <= r.decisive_own_loss:
		return "decisive_victory"
	if own >= r.decisive_enemy_loss and enemy <= r.decisive_own_loss:
		return "rout"
	if holds_field and own >= r.pyrrhic_own_loss:
		return "pyrrhic_victory"
	if absi(own - enemy) <= r.draw_band:
		return "draw"
	if enemy > own and enemy >= r.victory_min_loss:
		return "victory"
	if own > enemy and own >= r.victory_min_loss:
		return "defeat"
	return "marginal_victory" if enemy > own else "marginal_defeat"
