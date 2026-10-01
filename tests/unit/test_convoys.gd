extends GutTest
# M3 WP9: convoy escorts, patrols and fleet raiding (main spec 6.6; owner decisions 2026-10-01).

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match(players := 1) -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	if players > 1:
		settings.add_player(1, "core:species/human", "human")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _human(s: MatchState, i := 0) -> Empire:
	return s.empires.values()[i]


func _home_sys(s: MatchState, i := 0) -> int:
	return s.galaxy.planet(_human(s, i).capital_planet).system_id


func _own_at(s: MatchState, hops: int) -> int:
	var dist := AutoLogistics._hops_from(s, _home_sys(s), {})
	for sid: int in IdMap.sort_keys(dist.keys()):
		if dist[sid] == hops:
			s.galaxy.system(sid).owner = _human(s).id
			return sid
	return -1


func _fleet(s: MatchState, system: int, owner := -2) -> Fleet:
	var eid := _human(s).id if owner == -2 else owner
	var d: DesignDef = _db.get_def(&"core:design/human_cruiser_standard")
	var u := Shipyards.spawn(s, eid, String(d.hull), system)
	u.components.assign(Array(d.components).map(func(c: StringName) -> String: return String(c)))
	Fleets.arm(s, u)
	return Fleets.create(s, eid, [u.id], "test")


func _freighters(s: MatchState, sys: int, n: int, hub: int, owner := -2) -> Array:
	var eid := _human(s).id if owner == -2 else owner
	var out := []
	for i in n:
		var f := Shipyards.spawn(s, eid, "core:hull/freighter_light", sys)
		f.home = hub
		f.cargo = {"core:resource/ore": 1000}
		out.append(f.id)
	return out


## A hub with berths: the home of a starting freighter.
func _hub(s: MatchState, i := 0) -> int:
	for u: Unit in s.units.values():
		if u.kind == "freighter" and u.owner == _human(s, i).id and u.home != StateIO.NONE:
			return u.home
	return StateIO.NONE


func _lost(s: MatchState, ids: Array) -> int:
	return ids.filter(func(id: int) -> bool: return s.units.get_or(id) == null).size()


func _cmd(s: MatchState, type: StringName, payload: Dictionary, player := -2) -> bool:
	var c := CommandRegistry.create(type, _human(s).id if player == -2 else player, payload)
	if not c.validate(s):
		return false
	c.apply(s)
	return true


func test_commands_set_and_clear_missions() -> void:
	var s := _match()
	var f := _fleet(s, _home_sys(s))
	var hub := _hub(s)
	assert_true(_cmd(s, CmdSetEscort.TYPE, {"fleet": f.id, "hub": hub}))
	assert_eq(f.mission, "escort")
	assert_eq(f.escort_hub, hub)
	assert_false(_cmd(s, CmdSetEscort.TYPE, {"fleet": f.id, "hub": 999999}), "not a hub")
	var other := _own_at(s, 1)
	assert_true(_cmd(s, CmdSetPatrol.TYPE, {"fleet": f.id, "systems": [_home_sys(s), other]}))
	assert_eq(f.mission, "patrol")
	assert_eq(f.escort_hub, StateIO.NONE)
	Fleets.set_route(s, f, [other] as Array[int])
	assert_eq(f.mission, "", "a manual move ends the mission")
	var copy := Fleet.from_dict(f.to_dict())
	assert_eq(copy.patrol, f.patrol, "serialised")


func test_escort_cuts_raid_losses_and_hunts() -> void:
	var s := _match()
	var sys := _own_at(s, 1)
	var hub := _hub(s)
	Pirates.spawn_raider(s, sys, _human(s).id)
	var bare := _freighters(s, sys, 40, hub)
	Pirates.tick(s)
	var lost_bare := _lost(s, bare)
	var f := _fleet(s, _home_sys(s))
	_cmd(s, CmdSetEscort.TYPE, {"fleet": f.id, "hub": hub})
	s.clear_scratch()
	var escorted := _freighters(s, sys, 40, hub)
	Pirates.tick(s)
	var lost_escorted := _lost(s, escorted)
	assert_lt(lost_escorted, lost_bare, "escort: a quarter of the usual chance")
	assert_eq(Fleets.lead(s, f).path, Pathfinder.route(s.galaxy, _home_sys(s), sys), "the escort goes after the raider")
	assert_eq(f.mission, "escort", "and keeps its mission")


func test_patrol_cycles_and_adds_security() -> void:
	var s := _match()
	var home := _home_sys(s)
	var next := _own_at(s, 1)
	var before := Pirates.security(s, next)
	var f := _fleet(s, home)
	_cmd(s, CmdSetPatrol.TYPE, {"fleet": f.id, "systems": [home, next]})
	s.clear_scratch()
	assert_eq(Pirates.security(s, next), mini(before + 10, 100), "+10 security on the list")
	var visited := {}
	for h in 24 * 20:
		s.clear_scratch()
		Movement.tick(s)
		Fleets.mission_tick(s)
		var l := Fleets.lead(s, f)
		if not l.is_moving():
			visited[l.system_id] = true
	assert_true(visited.has(home) and visited.has(next), "cycled through both")
	assert_eq(f.mission, "patrol")


func test_warships_at_war_raid_convoys() -> void:
	var s := _match(2)
	var a := _human(s, 0).id
	var b := _human(s, 1).id
	var sys := _home_sys(s, 1)
	var ids := _freighters(s, sys, 40, _hub(s, 1), b)
	var losses_before := _human(s, 1).losses.size()
	_fleet(s, sys, a)
	for u: Unit in s.units.values():
		if u.kind == "freighter" and u.owner == b:
			u.raid_checked = StateIO.NONE
	Pirates.tick(s)
	assert_eq(_lost(s, ids), 0, "at peace: no raiding")
	for id: int in ids:
		s.units.get_or(id).raid_checked = StateIO.NONE
	assert_true(_cmd(s, CmdDeclareWar.TYPE, {"empire": b}, a))
	Pirates.tick(s)
	var lost := _lost(s, ids)
	assert_gt(lost, 0, "at war: freighters destroyed")
	var logged := _human(s, 1).losses.filter(func(l: Dictionary) -> bool: return int(l["unit"]) in ids)
	assert_eq(logged.size(), lost, "logged as losses, cargo with them")
	assert_gte(_human(s, 1).losses.size() - losses_before, lost)
