extends GutTest
# M4 WP6: war (Sub-spec E7): claims, casus belli, war score, exhaustion, peace terms.

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


## Player 0 (human), AI 1 (human), AI 2 (Krothi); all in contact, with influence.
func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	settings.add_player(1, "core:species/human", "ai")
	settings.add_player(2, "core:species/krothi", "ai")
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
	var out := [0, 0, 0]
	for e: Empire in s.empires.values():
		out[e.player_slot] = e.id
	return out


func _do(s: MatchState, eid: int, type: StringName, payload: Dictionary) -> Command:
	var c := CommandRegistry.create(type, eid, payload)
	if c.validate(s):
		c.apply(s)
	return c


## A system next to `owner`'s capital, given to `owner`.
func _border_system(s: MatchState, owner: int) -> int:
	var home := s.galaxy.planet(s.empire(owner).capital_planet).system_id
	var lid: int = s.galaxy.system(home).lane_ids[0]
	var sid := s.galaxy.lane(lid).other_end(home)
	s.galaxy.system(sid).owner = owner
	return sid


func _fleet(s: MatchState, eid: int, design: String, system: int, n: int) -> void:
	var d: DesignDef = _db.get_def(StringName(design))
	var ids := []
	for i in n:
		var u := Shipyards.spawn(s, eid, String(d.hull), system)
		u.components.assign(Array(d.components).map(func(c: StringName) -> String: return String(c)))
		Fleets.arm(s, u)
		ids.append(u.id)
	Fleets.create(s, eid, ids)


func test_claims_and_casus_belli() -> void:
	var s := _match()
	var ids := _ids(s)
	var sid := _border_system(s, ids[1])
	assert_false("claim" in Wars.casus_belli(s, ids[0], ids[1]))
	_do(s, ids[0], CmdClaimSystem.TYPE, {"system": sid})
	assert_eq(int(s.empire(ids[0]).treasury["core:resource/influence"]), 475 * 1000, "25 influence")
	assert_true("claim" in Wars.casus_belli(s, ids[0], ids[1]))
	Relations.month_tick(s)
	assert_eq(Relations.of(s, ids[1], ids[0]).standing.get("claims"), -20, "overlapping claims (E2)")
	_fleet(s, ids[2], "core:design/krothi_cruiser_standard", s.galaxy.planet(s.empire(ids[2]).capital_planet).system_id, 4)
	s.clear_scratch()
	assert_true("containment" in Wars.casus_belli(s, ids[0], ids[2]), "they are twice as strong")


func test_war_without_casus_belli_costs() -> void:
	var s := _match()
	var ids := _ids(s)
	_do(s, ids[0], CmdDeclareWar.TYPE, {"empire": ids[1]})
	assert_true(s.wars.has(Battles.war_key(ids[0], ids[1])))
	assert_eq(s.empire(ids[0]).reputation, -100)
	assert_eq(int(Relations.of(s, ids[2], ids[0]).events["warmonger"][0]), -20, "everyone else remembers")
	assert_ne(_do(s, ids[0], CmdDeclareWar.TYPE, {"empire": ids[2], "casus_belli": "claim"}).error, "", "no claim, no claim CB")


func test_battle_scores_and_exhausts() -> void:
	var s := _match()
	var ids := _ids(s)
	var sid := _border_system(s, ids[1])
	s.claims[Wars.claim_key(ids[0], sid)] = 0
	_fleet(s, ids[0], "core:design/human_cruiser_standard", sid, 4)
	_fleet(s, ids[1], "core:design/human_corvette_standard", sid, 2)
	_do(s, ids[0], CmdDeclareWar.TYPE, {"empire": ids[1], "casus_belli": "claim"})
	assert_eq(s.empire(ids[0]).reputation, 0, "with a casus belli: no penalty")
	for h in 120:
		s.clear_scratch()
		Battles.tick(s)
	var w := Wars.war_of(s, ids[0], ids[1])
	assert_gt(w.score_of(ids[0]), 0, "destroyed ships score")
	assert_eq(w.score_of(ids[1]), -w.score_of(ids[0]))
	assert_gt(s.empire(ids[1]).war_exhaustion, 0, "losses exhaust")


func test_blockade_scores_monthly() -> void:
	var s := _match()
	var ids := _ids(s)
	var sid := _border_system(s, ids[1])
	_do(s, ids[0], CmdDeclareWar.TYPE, {"empire": ids[1]})
	_fleet(s, ids[0], "core:design/human_destroyer_standard", sid, 1)
	Wars.month_tick(s)
	assert_eq(Wars.war_of(s, ids[0], ids[1]).score_of(ids[0]), 1, "+1 a month per blockaded system")


func test_peace_terms() -> void:
	var s := _match()
	var ids := _ids(s)
	var sid := _border_system(s, ids[1])
	s.claims[Wars.claim_key(ids[0], sid)] = 0
	_do(s, ids[0], CmdDeclareWar.TYPE, {"empire": ids[1], "casus_belli": "claim"})
	var w := Wars.war_of(s, ids[0], ids[1])
	var cede := [{"type": "cede_system", "ref": sid}]
	_do(s, ids[0], CmdOfferPeace.TYPE, {"empire": ids[1], "loser": ids[1], "terms": cede})
	assert_true(s.wars.has(Battles.war_key(ids[0], ids[1])), "no war score yet: refused")
	assert_ne(_do(s, ids[0], CmdOfferPeace.TYPE, {"empire": ids[1], "loser": ids[1], "terms": [{"type": "disarmament"}]}).error, "",
		"disarmament isn't a goal of a claim war")
	w.add_score(ids[0], 30000)
	_do(s, ids[0], CmdOfferPeace.TYPE, {"empire": ids[1], "loser": ids[1], "terms": cede})
	assert_false(s.wars.has(Battles.war_key(ids[0], ids[1])), "accepted")
	assert_eq(s.galaxy.system(sid).owner, ids[0], "the claimed system is ceded")
	assert_lt(Relations.opinion(s, ids[1], ids[0]), -30, "war memory: opinion recovers from about -50")


func test_reparations_and_humiliation() -> void:
	var s := _match()
	var ids := _ids(s)
	_do(s, ids[0], CmdDeclareWar.TYPE, {"empire": ids[1]})
	var w := Wars.war_of(s, ids[0], ids[1])
	w.add_score(ids[0], 50000)
	var terms := [{"type": "reparations", "amount": 6000}, {"type": "humiliation"}]
	assert_eq(Wars.terms_cost(s, terms), 30 + 10)
	_do(s, ids[0], CmdOfferPeace.TYPE, {"empire": ids[1], "loser": ids[1], "terms": terms})
	assert_false(s.wars.has(Battles.war_key(ids[0], ids[1])))
	assert_eq(s.deals.size(), 1, "reparations: 100 credits a month for 60 months")
	assert_eq(int(s.empire(ids[1]).treasury["core:resource/influence"]), 450 * 1000, "humiliation: -50 influence")


func test_disarmament_caps_the_fleet() -> void:
	var s := _match()
	var ids := _ids(s)
	_fleet(s, ids[2], "core:design/krothi_cruiser_standard", s.galaxy.planet(s.empire(ids[2]).capital_planet).system_id, 4)
	s.clear_scratch()
	_do(s, ids[1], CmdDeclareWar.TYPE, {"empire": ids[2], "casus_belli": "containment"})
	var w := Wars.war_of(s, ids[1], ids[2])
	assert_not_null(w)
	w.add_score(ids[1], 40000)
	s.clear_scratch()
	Wars.make_peace(s, w, ids[2], [{"type": "disarmament"}])
	assert_gt(s.empire(ids[2]).disarm_cap, 0)
	assert_ne(Wars.check_disarmament(s, ids[2], 999999), "", "capped at half its fleet")


func test_forced_peace_at_full_exhaustion() -> void:
	var s := _match()
	var ids := _ids(s)
	_do(s, ids[0], CmdDeclareWar.TYPE, {"empire": ids[1]})
	s.empire(ids[1]).war_exhaustion = 100000
	assert_eq(Wars.stability_penalty(s, ids[1]), -15)
	Wars.month_tick(s)
	s.tick += 6 * Calendar.HOURS_PER_MONTH
	Wars.month_tick(s)
	assert_false(s.wars.has(Battles.war_key(ids[0], ids[1])), "status quo peace after 6 months at 100")
