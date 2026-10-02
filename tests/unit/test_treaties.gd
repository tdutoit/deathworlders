extends GutTest
# M4 WP4: treaties (Sub-spec E3-E5, E8).

var _db: DefDatabase
const NAP := "core:treaty/nonaggression"
const TRADE := "core:treaty/trade"
const PACT := "core:treaty/defence_pact"
const PROTECT := "core:treaty/protectorate"
const ACCESS := "core:treaty/access"


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


## Three empires: 0 human (player), 1 human (AI), 2 Krothi (AI). All in contact.
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


func test_ai_answers_by_e5_and_proposer_pays() -> void:
	var s := _match()
	var ids := _ids(s)
	var acc := Treaties.acceptance(s, ids[0], ids[1], NAP)
	assert_eq(acc["blocked"], "")
	var keys: Array = (acc["parts"] as Array).map(func(p: Array) -> String: return p[0])
	assert_has(keys, "ACCEPT_OPINION")
	assert_has(keys, "ACCEPT_PERSONALITY")
	_do(s, ids[0], CmdProposeTreaty.TYPE, {"to": ids[1], "treaty": NAP})
	assert_eq(Treaties.between(s, ids[0], ids[1], NAP).size(), 1, "human AI accepts a non-aggression pact")
	assert_eq(int(s.empire(ids[0]).treasury["core:resource/influence"]), 490 * 1000, "proposer pays 10 influence")
	var alliance := Treaties.acceptance(s, ids[0], ids[1], "core:treaty/alliance")
	assert_ne(alliance["blocked"], "", "alliance needs opinion +50 and trust 60 (E4 gates)")


func test_nonaggression_blocks_war_and_breaking_costs() -> void:
	var s := _match()
	var ids := _ids(s)
	Treaties.sign(s, ids[0], ids[1], NAP)
	assert_ne(_do(s, ids[0], CmdDeclareWar.TYPE, {"empire": ids[1]}).error, "", "no war under a non-aggression pact")
	var t: Treaty = Treaties.between(s, ids[0], ids[1])[0]
	_do(s, ids[0], CmdCancelTreaty.TYPE, {"treaty": t.id})
	assert_true(Treaties.between(s, ids[0], ids[1]).is_empty(), "cancelled before 5 years: broken")
	assert_eq(Relations.trust(s, ids[1], ids[0]), 0, "victim's trust to 0")
	assert_eq(Relations.trust(s, ids[2], ids[0]), 0, "everyone else -20 trust (from 20)")
	assert_eq(s.empire(ids[0]).reputation, -50)
	assert_lt(Relations.opinion(s, ids[1], ids[0]), 0, "treaty broken: -15")


func test_notice_after_minimum_duration() -> void:
	var s := _match()
	var ids := _ids(s)
	var t := Treaties.sign(s, ids[0], ids[1], NAP)
	s.tick += 5 * Calendar.HOURS_PER_YEAR
	Treaties.cancel(s, t, ids[0])
	assert_eq(t.ends_tick, s.tick + 12 * Calendar.HOURS_PER_MONTH, "12 months' notice")
	assert_ne(Treaties.check_war(s, ids[0], ids[1]), "", "still binding during the notice")
	s.tick = t.ends_tick
	Treaties.month_tick(s)
	assert_true(Treaties.between(s, ids[0], ids[1]).is_empty(), "lapsed cleanly")
	assert_eq(s.empire(ids[0]).reputation, 0, "no penalty")


func test_treaties_build_trust_and_opinion() -> void:
	var s := _match()
	var ids := _ids(s)
	Treaties.sign(s, ids[0], ids[1], NAP)
	Treaties.sign(s, ids[0], ids[1], TRADE)
	var before := Relations.trust(s, ids[1], ids[0])
	Relations.month_tick(s)
	Treaties.month_tick(s)
	assert_eq(Relations.trust(s, ids[1], ids[0]), before + 2, "+1 a month per treaty")
	assert_eq(Relations.of(s, ids[1], ids[0]).standing.get("treaty_trade"), 10, "trade agreement +10 opinion")


func test_player_answers_proposals() -> void:
	var s := _match()
	var ids := _ids(s)
	_do(s, ids[1], CmdProposeTreaty.TYPE, {"to": ids[0], "treaty": TRADE})
	assert_eq(s.proposals.size(), 1, "the player decides")
	var p: Proposal = s.proposals.values()[0]
	_do(s, ids[0], CmdAnswerProposal.TYPE, {"proposal": p.id, "accept": 0})
	assert_eq(int(Relations.of(s, ids[1], ids[0]).events["denied"][0]), -15, "they remember the refusal")
	_do(s, ids[1], CmdProposeTreaty.TYPE, {"to": ids[0], "treaty": NAP})
	p = s.proposals.values()[0]
	_do(s, ids[0], CmdAnswerProposal.TYPE, {"proposal": p.id, "accept": 1})
	assert_eq(Treaties.between(s, ids[0], ids[1], NAP).size(), 1)


func test_calls_to_arms() -> void:
	var s := _match()
	var ids := _ids(s)
	Treaties.sign(s, ids[1], ids[0], PACT)  # the player and the human AI
	_do(s, ids[2], CmdDeclareWar.TYPE, {"empire": ids[1]})
	assert_eq(s.calls.size(), 1, "the player is called to defend the AI")
	var c: CallToArms = s.calls.values()[0]
	assert_eq(c.to, ids[0])
	var trust := Relations.trust(s, ids[1], ids[0])
	_do(s, ids[0], CmdAnswerCall.TYPE, {"call": c.id, "join": 1})
	assert_true(s.wars.has(Battles.war_key(ids[0], ids[2])), "joined the war")
	assert_eq(Relations.trust(s, ids[1], ids[0]), trust + 5)


func test_ignored_call_costs_trust() -> void:
	var s := _match()
	var ids := _ids(s)
	Treaties.sign(s, ids[1], ids[0], PACT)
	_do(s, ids[2], CmdDeclareWar.TYPE, {"empire": ids[1]})
	var trust := Relations.trust(s, ids[1], ids[0])
	s.tick += 31 * Calendar.HOURS_PER_DAY
	Treaties.month_tick(s)
	assert_eq(s.calls.size(), 0)
	assert_eq(Relations.trust(s, ids[1], ids[0]), maxi(0, trust - 30), "ignored: -30 trust")


func test_protectorate() -> void:
	var s := _match()
	var ids := _ids(s)
	assert_ne(Treaties.check_propose(s, ids[1], ids[0], PROTECT), "", "not threatened: no protection")
	# Krothi (2) build a fleet and turn hostile; the human AI (1) is weak and asks the player (0).
	var home2 := s.galaxy.planet(s.empire(ids[2]).capital_planet).system_id
	var d: DesignDef = _db.get_def(&"core:design/krothi_cruiser_standard")
	for i in 4:
		var u := Shipyards.spawn(s, ids[2], String(d.hull), home2)
		u.components.assign(Array(d.components).map(func(cc: StringName) -> String: return String(cc)))
	Relations.add_event(s, ids[1], ids[2], "humiliated", -40)
	Relations.add_event(s, ids[1], ids[0], "gift", 25)
	var home1 := s.galaxy.planet(s.empire(ids[1]).capital_planet).system_id
	var lid: int = s.galaxy.system(home1).lane_ids[0]
	s.galaxy.system(s.galaxy.lane(lid).other_end(home1)).owner = ids[0]  # the guardian next door (E8: within 6 lanes)
	s.clear_scratch()
	assert_eq(Treaties.check_protectorate(s, ids[1], ids[0]), "")
	var t := Treaties.sign(s, ids[1], ids[0], PROTECT)
	s.empire(ids[1]).credit_net = 50 * 1000
	var before := int(s.empire(ids[0]).treasury["core:resource/credits"])
	Treaties.month_tick(s)
	assert_eq(int(s.empire(ids[0]).treasury["core:resource/credits"]) - before, 5 * 1000, "10% tribute")
	_do(s, ids[2], CmdDeclareWar.TYPE, {"empire": ids[1]})
	assert_eq(t.attacked_tick, s.tick, "the guardian's clock starts")
	s.tick += 61 * Calendar.HOURS_PER_DAY
	Treaties.month_tick(s)
	assert_null(s.treaties.get_or(t.id), "no guardian fleet in 60 days: the protectorate fails")
	assert_eq(s.empire(ids[0]).reputation, -75)


func test_military_access_resupplies() -> void:
	var s := _match()
	var ids := _ids(s)
	var home1 := s.galaxy.planet(s.empire(ids[1]).capital_planet).system_id
	var d: DesignDef = _db.get_def(&"core:design/human_destroyer_standard")
	var u := Shipyards.spawn(s, ids[0], String(d.hull), home1)
	u.components.assign(Array(d.components).map(func(cc: StringName) -> String: return String(cc)))
	Fleets.arm(s, u)
	s.colony(s.empire(ids[1]).capital_planet).stockpile.add("core:resource/munitions", 100 * 1000)
	u.ammo = 0
	FleetSupply.day_tick(s)
	assert_eq(u.unsupplied_days, 1, "foreign space: no supply")
	Treaties.sign(s, ids[0], ids[1], ACCESS)
	FleetSupply.day_tick(s)
	assert_eq(u.unsupplied_days, 0, "military access: their stockpiles supply us")
	assert_gt(u.ammo, 0)


func _fleet_at(s: MatchState, eid: int, design: String, system: int, n: int) -> void:
	var d: DesignDef = _db.get_def(StringName(design))
	var ids := []
	for i in n:
		var u := Shipyards.spawn(s, eid, String(d.hull), system)
		u.components.assign(Array(d.components).map(func(cc: StringName) -> String: return String(cc)))
		Fleets.arm(s, u)
		ids.append(u.id)
	Fleets.create(s, eid, ids)


## Coalition battles (owner decision 2026-10-02): allies at war with the same enemy fight on one side.
func test_coalition_battle() -> void:
	var s := _match()
	var ids := _ids(s)
	Treaties.sign(s, ids[0], ids[1], PACT)
	s.wars[Battles.war_key(ids[0], ids[2])] = true
	s.wars[Battles.war_key(ids[1], ids[2])] = true
	var arena := -1
	for sid: int in s.galaxy.systems.ordered():
		if s.galaxy.system(sid).owner == StateIO.NONE:
			arena = sid
			break
	_fleet_at(s, ids[0], "core:design/human_cruiser_standard", arena, 3)
	_fleet_at(s, ids[1], "core:design/human_cruiser_standard", arena, 3)
	_fleet_at(s, ids[2], "core:design/krothi_corvette_standard", arena, 2)
	s.clear_scratch()
	Battles.tick(s)
	assert_eq(s.battles.size(), 1, "one battle")
	var b: Battle = s.battles.values()[0]
	var allies := b.side_of_owner(ids[0])
	assert_eq(b.side_of_owner(ids[1]), allies, "allies on one side")
	assert_eq(b.side_of_owner(ids[2]), 1 - allies)
	for h in 120:
		s.clear_scratch()
		Battles.tick(s)
	var rep: BattleReport = s.reports.values()[0]
	assert_eq(rep.side_of(ids[1]), rep.side_of(ids[0]))
	assert_eq(rep.all_owners().size(), 3)
	assert_gt(s.empire(ids[0]).tech_fragments + s.empire(ids[1]).tech_fragments, 0, "salvage shared by the winners")
