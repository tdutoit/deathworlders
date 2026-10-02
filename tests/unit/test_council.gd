extends GutTest
# M4 WP8: the minimal Galactic Council (Sub-spec E9).

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


## Slot 0 player (human), slot 1 AI Vess'kar, slot 2 AI Thessari, slot 3 AI Krothi; all in contact.
func _match(with_vesskar := true) -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	settings.add_player(1, "core:species/vesskar" if with_vesskar else "core:species/ohlan", "ai")
	settings.add_player(2, "core:species/thessari", "ai")
	settings.add_player(3, "core:species/krothi", "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	var ids := _ids(s)
	for a in ids:
		for b in ids:
			if a != b:
				Relations._meet(s, a, b)
		s.empire(a).treasury["core:resource/influence"] = 500 * 1000
	return s


func _ids(s: MatchState) -> Array:
	var out := [0, 0, 0, 0]
	for e: Empire in s.empires.values():
		out[e.player_slot] = e.id
	return out


func _do(s: MatchState, eid: int, type: StringName, payload: Dictionary) -> Command:
	var c := CommandRegistry.create(type, eid, payload)
	if c.validate(s):
		c.apply(s)
	return c


func test_founding() -> void:
	var s := _match()
	var ids := _ids(s)
	assert_eq(s.council.members, [ids[1]] as Array[int], "the Vess'kar found the Council (E9)")
	var t := _match(false)
	var tids := _ids(t)
	assert_eq(t.council.members, [tids[0]] as Array[int], "no Vess'kar: highest Ambition (humans and Ohlan 60: lowest ID)")
	assert_gt(s.council.next_session, s.tick)


func test_recognition_vote() -> void:
	var s := _match()
	var ids := _ids(s)
	assert_ne(_do(s, ids[0], CmdCouncilPropose.TYPE, {"resolution": "core:resolution/recognition", "target": ids[0]}).error, "",
		"non-members can't propose")
	_do(s, ids[1], CmdCouncilPropose.TYPE, {"resolution": "core:resolution/recognition", "target": ids[2]})
	assert_eq(s.council.proposals.size(), 1)
	assert_eq(int(s.empire(ids[1]).treasury["core:resource/influence"]), 470 * 1000, "30 influence")
	Councils.session(s)
	assert_true(ids[2] in s.council.members, "the proposer votes for its own resolution")
	assert_eq(s.council.sessions, 1)
	assert_eq((s.council.last_session[0] as Dictionary)["passed"], true)


func after_each() -> void:
	SignatureMechanics.register(&"precedence", PrecedenceMechanic)


func test_resolution_effects_and_repeal() -> void:
	SignatureMechanics.register(&"precedence", SignatureMechanic)  # plain votes here; Precedence: test_signatures
	var s := _match()
	var ids := _ids(s)
	s.council.members.append(ids[0])
	_do(s, ids[1], CmdCouncilPropose.TYPE, {"resolution": "core:resolution/trade_standards"})
	_do(s, ids[0], CmdCouncilVote.TYPE, {"proposal": s.council.proposals[0]["id"], "vote": 1})
	Councils.session(s)
	assert_eq(Councils.in_force(s, "trade_standards").size(), 1)
	assert_eq(Councils.clerk_credits_permille(s, ids[0]), 100, "members' Clerks +10%")
	assert_eq(Councils.clerk_credits_permille(s, ids[3]), -100, "others -10%")
	s.council.members.append(ids[2])  # the Thessari (greed 20) dislike Trade Standards
	var active_id: int = s.council.active[0]["id"]
	_do(s, ids[0], CmdCouncilPropose.TYPE, {"repeal": active_id})
	Councils.session(s)
	assert_eq(Councils.in_force(s, "trade_standards").size(), 0, "repealed")


func test_pirate_suppression() -> void:
	var s := _match()
	var ids := _ids(s)
	var vhome := s.galaxy.planet(s.empire(ids[1]).capital_planet).system_id
	var before := Pirates.security(s, vhome)
	s.council.active.append({"id": 1, "def": "core:resolution/pirate_suppression", "target": -1, "proposer": ids[1], "tick": 0, "for": [ids[1]]})
	s.clear_scratch()
	assert_eq(Pirates.security(s, vhome), mini(100, before + 10), "+10 security in member space")


func test_sanctions_and_defiance() -> void:
	var s := _match()
	var ids := _ids(s)
	s.council.members.append(ids[2])
	s.council.active.append({"id": 7, "def": "core:resolution/sanctions", "target": ids[3], "proposer": ids[1], "tick": 0,
		"for": [ids[1]]})
	Relations.month_tick(s)
	assert_eq(Relations.of(s, ids[1], ids[3]).standing.get("sanctions"), -20, "members -20 toward the sanctioned")
	var trust := Relations.trust(s, ids[1], ids[2])
	Treaties.sign(s, ids[2], ids[3], "core:treaty/nonaggression")
	assert_eq(int(Relations.of(s, ids[1], ids[2]).events["defiance"][0]), -15, "defiance: -15 from those who voted for it")
	assert_eq(Relations.trust(s, ids[1], ids[2]), trust - 10)


func test_votes() -> void:
	var s := _match()
	var ids := _ids(s)
	assert_gte(Councils.votes(s, ids[1]), 1)
	Treaties.sign(s, ids[3], ids[1], "core:treaty/protectorate")
	assert_eq(Councils.votes(s, ids[1]) - Councils.votes(s, ids[2]) >= 1, true, "a guardian has a vote per protectorate")
