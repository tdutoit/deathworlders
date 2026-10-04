extends SceneTree
## Diplomacy harness (M4 WP14, Sub-spec E16). Usage:
##   godot --headless -s tools/diplomacy_harness.gd -- [mode=ai] [seeds=4] [years=30] [size=medium] [players=6] [first=1]
## ai: all-AI matches on Officer. Reports the first war, every war (year, sides, casus belli, unprovoked, on a
##   human-species neighbour, outcome), treaties signed and broken, and the Council pass rate.
##   E16: no unprovoked AI war on a human-species neighbour before year 10; resolutions pass 40-60%.
## honour: slot 0 is a scripted honourable player (human species, player controller): the economy and military
##   autopilots run its empire, it proposes each treaty in order once the AI would accept it (the live verdict the
##   Diplomacy screen shows), tops up its gift opinion with the one AI it courts monthly (credits, then surplus goods), accepts every proposal and call to arms and
##   white peace, and never breaks its word except once: it breaks its first alliance at once, then rebuilds.
##   E16: an alliance by year 30; the victim's trust takes 15-25 years to return to the alliance's minimum.
## Exit code 1 if a target is missed.

const SPECIES: Array[String] = ["human", "krothi", "vesskar", "thessari", "ohlan", "human", "krothi", "vesskar"]
const TREATY_ORDER: Array[String] = ["core:treaty/nonaggression", "core:treaty/trade", "core:treaty/access",
	"core:treaty/defence_pact", "core:treaty/alliance"]
const ALLIANCE := "core:treaty/alliance"
const RESPONSES: Array[String] = ["retaliation", "protectorate", "call_to_arms"]  # wars that answer a provocation
const GIFT_PER_OPINION := 25  # credits per opinion point (E2: +1 per 25 credit-value)
const GIFT_RESERVE := 200  # credits the bot keeps
const GIFT_GOODS: Array[String] = ["core:resource/food", "core:resource/ore", "core:resource/alloys"]
const GOODS_MONTHS := 6  # goods beyond this many months of the bot's own use are surplus
const GOODS_RESERVE := 100  # ... plus this many units kept
const GOODS_MAX := 300  # largest goods gift a month (a freighter load or two)
const FIRST_WAR_YEAR_MIN := 10
const PASS_MIN := 40
const PASS_MAX := 60
const ALLIANCE_BY_YEAR := 30
const REBUILD_MIN_YEARS := 15
const REBUILD_MAX_YEARS := 25

var gifts_sent := 0
var courted := -1  # the AI the bot courts until allied (a player sticks with one prospective ally)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "ai"
	var seeds := int(args[1]) if args.size() > 1 else 4
	var years := int(args[2]) if args.size() > 2 else 30
	var size := args[3] if args.size() > 3 else "medium"
	var players := int(args[4]) if args.size() > 4 else 6
	var first := int(args[5]) if args.size() > 5 else 1
	var loader := ContentLoader.new()
	loader.load_mods([])
	var ok := true
	var passed := 0
	var voted := 0
	for i in seeds:
		var r := run(loader.db, mode, i + first, years, size, players)
		print("seed %d (%s, %s, %d years, %.1f s)" % [i + first, mode, size, years, r["seconds"]])
		for line: String in r["lines"]:
			print("  " + line)
		ok = ok and r["ok"]
		passed += int(r["passed"])
		voted += int(r["voted"])
	if mode == "ai":
		var rate := passed * 100 / maxi(1, voted)
		var rate_ok := voted == 0 or (rate >= PASS_MIN and rate <= PASS_MAX)
		print("Council: %d of %d resolutions passed (%d%%, E16 %d-%d%%) %s" % [passed, voted, rate, PASS_MIN, PASS_MAX, "OK" if rate_ok else "MISS"])
		ok = ok and rate_ok
	print("E16 %s" % ("met" if ok else "MISSED"))
	quit(0 if ok else 1)


func run(db: DefDatabase, mode: String, seed_value: int, years: int, size: String, players: int) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	gifts_sent = 0
	courted = StateIO.NONE
	var settings := MatchSettings.new()
	settings.galaxy_size = "core:match_preset/size_" + size
	for i in players:
		var bot := mode == "honour" and i == 0
		settings.add_player(i, "core:species/" + SPECIES[i % SPECIES.size()], "player" if bot else "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, seed_value, db, errors)
	var bot_id := StateIO.NONE
	if mode == "honour":
		for e: Empire in s.empires.values():
			if e.player_slot == 0:
				bot_id = e.id
	var none: Array[Command] = []
	var lines: Array[String] = []
	var wars := {}  # war ID -> record
	var treaties := {}  # treaty ID -> [def, start tick, a, b]
	var signed := {}  # treaty def -> count
	var broken := 0
	var council_seen := 0
	var passed := 0
	var voted := 0
	var ok := true
	var first_unprovoked_human := -1
	var alliance_month := -1
	var betrayed := StateIO.NONE  # the AI whose alliance the bot broke
	var betrayal_month := -1
	var rebuilt_month := -1
	var min_years := {}  # treaty def -> min years
	for id: StringName in db.ids("treaty"):
		min_years[String(id)] = (db.get_def(id) as TreatyDef).min_years
	var alliance_trust := (db.get_def(&"core:treaty/alliance") as TreatyDef).min_trust
	for m in years * Calendar.MONTHS_PER_YEAR:
		for h in Calendar.HOURS_PER_MONTH:
			Sim.step(s, none)
		var year := m / Calendar.MONTHS_PER_YEAR + 1
		# Wars: new and ended.
		var live := {}
		for wid: int in s.war_info.ordered():
			var w: War = s.war_info.get_or(wid)
			live[w.id] = true
			if not wars.has(w.id):
				var att := s.empire(w.attacker)
				var def := s.empire(w.defender)
				var unprovoked := not w.casus_belli in RESPONSES
				var rel := Relations.of(s, w.attacker, w.defender)
				var neighbour := rel != null and rel.standing.has("border")
				var on_human := unprovoked and neighbour and def.species == "core:species/human" and Autopilot.is_ai(s, w.attacker)
				if on_human and first_unprovoked_human < 0:
					first_unprovoked_human = year
				wars[w.id] = {"year": year, "att": _sp(att), "def": _sp(def), "cb": w.casus_belli, "unprovoked": unprovoked,
					"on_human": on_human, "score": 0, "start": m}
			wars[w.id]["score"] = w.score_milli
		for wid: int in wars.keys():
			var rec: Dictionary = wars[wid]
			if not live.has(wid) and not rec.has("end"):
				rec["end"] = m
		# Treaties: new, and gone before their minimum duration (broken).
		var t_live := {}
		for tid: int in s.treaties.ordered():
			var t: Treaty = s.treaties.get_or(tid)
			t_live[tid] = true
			if not treaties.has(tid):
				treaties[tid] = [t.def_id, t.start_tick, t.a, t.b]
				signed[t.def_id] = int(signed.get(t.def_id, 0)) + 1
				if bot_id != StateIO.NONE and t.def_id == ALLIANCE and (t.a == bot_id or t.b == bot_id) and alliance_month < 0:
					alliance_month = m
		for tid: int in IdMap.sort_keys(treaties.keys()):
			var rec: Array = treaties[tid]
			if not t_live.has(tid) and rec.size() == 4:
				rec.append(s.tick)
				var age_years := (s.tick - int(rec[1])) / (Calendar.HOURS_PER_MONTH * Calendar.MONTHS_PER_YEAR)
				if age_years < int(min_years.get(rec[0], 0)) and s.empire(int(rec[2])) != null and s.empire(int(rec[3])) != null:
					broken += 1
		# Council sessions.
		if s.council != null and s.council.sessions > council_seen:
			council_seen = s.council.sessions
			var votes := []
			for r: Dictionary in s.council.last_session:
				voted += 1
				passed += 1 if r["passed"] else 0
				votes.append("%s by %s %d-%d%s" % [String(r["def"]).get_slice("/", 1), _sp(s.empire(int(r["proposer"]))), int(r["yes"]),
					int(r["no"]), " passed" if r["passed"] else ""])
			lines.append("council session %d (year %d, %d members): %s" % [council_seen, year, s.council.members.size(),
				", ".join(votes) if not votes.is_empty() else "no proposals"])
		if bot_id != StateIO.NONE:
			var res := _bot(s, bot_id, betrayed)
			if betrayed == StateIO.NONE and res != StateIO.NONE:
				betrayed = res
				betrayal_month = m
				if alliance_month < 0:
					alliance_month = m  # accepted and broken in the same month
			if betrayed != StateIO.NONE and rebuilt_month < 0 and m > betrayal_month \
					and Relations.trust(s, betrayed, bot_id) >= alliance_trust:
				rebuilt_month = m
	# Report.
	if mode == "ai":
		var first_war := -1
		for wid: int in IdMap.sort_keys(wars.keys()):
			var w: Dictionary = wars[wid]
			if first_war < 0:
				first_war = w["year"]
			var outcome := "ongoing" if not w.has("end") else "ended after %d months, score %d" % [int(w["end"]) - int(w["start"]), int(w["score"]) / 1000]
			lines.append("war y%d %s -> %s cb '%s'%s%s, %s" % [w["year"], w["att"], w["def"], w["cb"], " unprovoked" if w["unprovoked"] else "",
				" ON HUMAN NEIGHBOUR" if w["on_human"] else "", outcome])
		lines.append("first war: %s" % ("none" if first_war < 0 else "year %d" % first_war))
		var human_ok := first_unprovoked_human < 0 or first_unprovoked_human >= FIRST_WAR_YEAR_MIN
		lines.append("first unprovoked AI war on a human neighbour: %s (E16 >= year %d) %s" % [
			"none" if first_unprovoked_human < 0 else "year %d" % first_unprovoked_human, FIRST_WAR_YEAR_MIN, "OK" if human_ok else "MISS"])
		ok = ok and human_ok
	else:
		var ally_ok := alliance_month >= 0 and alliance_month / Calendar.MONTHS_PER_YEAR + 1 <= ALLIANCE_BY_YEAR
		lines.append("bot alliance: %s (E16 by year %d) %s" % ["none" if alliance_month < 0 else "year %d" % (alliance_month / 12 + 1),
			ALLIANCE_BY_YEAR, "OK" if ally_ok else "MISS"])
		ok = ok and ally_ok
		if betrayed != StateIO.NONE:
			var yrs := -1 if rebuilt_month < 0 else (rebuilt_month - betrayal_month) / Calendar.MONTHS_PER_YEAR
			var rb_ok := rebuilt_month < 0 and years * 12 - betrayal_month >= REBUILD_MAX_YEARS * 12 or yrs >= REBUILD_MIN_YEARS and yrs <= REBUILD_MAX_YEARS
			if rebuilt_month < 0 and years * 12 - betrayal_month < REBUILD_MAX_YEARS * 12:
				rb_ok = years * 12 - betrayal_month >= REBUILD_MIN_YEARS * 12  # still rebuilding; ok once past the minimum
			lines.append("broke the alliance in year %d; trust back to %d %s (E16 %d-%d years) %s; trust now %d" % [betrayal_month / 12 + 1, alliance_trust,
				"not yet" if rebuilt_month < 0 else "after %d years" % yrs, REBUILD_MIN_YEARS, REBUILD_MAX_YEARS, "OK" if rb_ok else "MISS",
				Relations.trust(s, betrayed, bot_id)])
			ok = ok and rb_ok
		for e: Empire in s.empires.values():
			if e.id != bot_id and Relations.has_contact(s, e.id, bot_id):
				lines.append("  %s view of the bot: opinion %d trust %d" % [_sp(e), Relations.opinion(s, e.id, bot_id), Relations.trust(s, e.id, bot_id)])
				lines.append("    %s" % str(Relations.breakdown(s, e.id, bot_id)))
	var tl := []
	for d: String in IdMap.sort_keys(signed.keys()):
		tl.append("%s %d" % [d.get_slice("/", 1), signed[d]])
	lines.append("treaties signed: %s; broken %d" % [", ".join(tl), broken])
	var pairs := 0
	for k: String in s.relations.keys():
		pairs += 1
	lines.append("relations (directed pairs in contact): %d" % pairs)
	if bot_id != StateIO.NONE:
		lines.append("bot gifts sent: %d, treasury %d" % [gifts_sent, int(s.empire(bot_id).treasury.get(Deals.CREDITS, 0)) / 1000])
	return {"lines": lines, "ok": ok, "passed": passed, "voted": voted, "seconds": (Time.get_ticks_usec() - t0) / 1000000.0}


## The honourable bot's month (harness only: it plays through Commands like a player would, plus the autopilots
## that run AI empires' economies). Returns the AI whose alliance it broke this month, or NONE.
func _bot(s: MatchState, me: int, betrayed: int) -> int:
	Autopilot._directive(s, me)
	MilitaryAutopilot.month_tick(s, me, Autopilot.can_expand(s, me))
	if Autopilot.can_expand(s, me):
		Autopilot._colonise(s, me)
		Autopilot._outpost(s, me)
		Autopilot._mining(s, me)
		Autopilot._freighters(s, me)
		Autopilot._logistics(s, me)
		Autopilot._shipyards(s, me)
	for pid: int in s.proposals.ordered():
		var p: Proposal = s.proposals.get_or(pid)
		if p != null and p.to == me:
			_cmd(s, me, CmdAnswerProposal.TYPE, {"proposal": p.id, "accept": 1})
	for cid: int in s.calls.ordered():
		var c: CallToArms = s.calls.get_or(cid)
		if c != null and c.to == me:
			_cmd(s, me, CmdAnswerCall.TYPE, {"call": c.id, "join": 1})
	for oid: int in s.peace_offers.ordered():
		var o: PeaceOffer = s.peace_offers.get_or(oid)
		if o != null and o.to == me:
			_cmd(s, me, CmdAnswerPeace.TYPE, {"offer": o.id, "accept": 1})
	for wid: int in s.war_info.ordered():
		var w: War = s.war_info.get_or(wid)
		if w.attacker == me or w.defender == me:
			_cmd(s, me, CmdOfferPeace.TYPE, {"empire": w.defender if w.attacker == me else w.attacker,
				"loser": me, "terms": []})
	# Break the first alliance once (the E16 trust measurement), then keep every word.
	if betrayed == StateIO.NONE:
		for tid: int in s.treaties.ordered():
			var t: Treaty = s.treaties.get_or(tid)
			if t.def_id == ALLIANCE and (t.a == me or t.b == me):
				var victim := t.other(me)
				return victim if _cmd(s, me, CmdCancelTreaty.TYPE, {"treaty": t.id}) else StateIO.NONE
	# Court the AI with the best opinion of us: the next treaty it would accept, and a monthly gift.
	var best := StateIO.NONE
	var best_op := -1000
	for e: Empire in s.empires.values():
		if e.id == me or not Relations.has_contact(s, e.id, me) or s.wars.has(Battles.war_key(e.id, me)):
			continue
		for def_id in TREATY_ORDER:
			if not _has_treaty(s, me, e.id, def_id) and Treaties.check_propose(s, me, e.id, def_id) == "" \
					and Treaties.accepts(s, me, e.id, def_id):
				_cmd(s, me, CmdProposeTreaty.TYPE, {"to": e.id, "treaty": def_id})
				break
		var op := Relations.opinion(s, e.id, me)
		if not _has_treaty(s, me, e.id, ALLIANCE) and e.id != betrayed and op > best_op:
			best = e.id
			best_op = op
	if courted != StateIO.NONE and (s.empire(courted) == null or _has_treaty(s, me, courted, ALLIANCE) or courted == betrayed \
			or s.wars.has(Battles.war_key(courted, me))):
		courted = StateIO.NONE
	if courted == StateIO.NONE:
		courted = best
	best = courted
	if best == StateIO.NONE and betrayed != StateIO.NONE and not _has_treaty(s, me, betrayed, ALLIANCE):
		best = betrayed  # make amends
	if best != StateIO.NONE:
		# Top the gift modifier up to its cap (what a player courting an ally does), within the treasury.
		var rel := Relations.of(s, best, me)
		var have: int = int((rel.events.get("gift", [0, 0]) as Array)[0]) if rel != null else 0
		var cap := int(Relations.rules(s).event_cap.get(&"gift", 25))
		var spare := int(s.empire(me).treasury.get(Deals.CREDITS, 0)) / Stockpile.MILLI - GIFT_RESERVE
		var amount := mini((cap - have) * GIFT_PER_OPINION, spare)
		if amount >= GIFT_PER_OPINION and _cmd(s, me, CmdProposeDeal.TYPE, {"to": best, "treaty": "", "items": [
				{"giver": me, "kind": "credits", "ref": "", "amount": amount, "months": 0}]}):
			gifts_sent += 1
			have += amount / GIFT_PER_OPINION
		# Credits run short: surplus goods (beyond six months' use) make up the rest, delivered by convoy.
		for res in GIFT_GOODS:
			if have >= cap:
				break
			var used := 0
			for pid: int in s.colonies.ordered():
				var c: Colony = s.colonies.get_or(pid)
				if c.owner == me:
					used += int(c.last_consumed.get(res, 0))
			var surplus := (Deals.total_stock(s, me, res) - used * GOODS_MONTHS) / Stockpile.MILLI - GOODS_RESERVE
			var n := mini(surplus, GOODS_MAX)
			if n >= GIFT_PER_OPINION and _cmd(s, me, CmdProposeDeal.TYPE, {"to": best, "treaty": "", "items": [
					{"giver": me, "kind": "resource", "ref": res, "amount": n, "months": 0}]}):
				gifts_sent += 1
				have = int((Relations.of(s, best, me).events.get("gift", [0, 0]) as Array)[0])
	return StateIO.NONE


func _has_treaty(s: MatchState, a: int, b: int, def_id: String) -> bool:
	for tid: int in s.treaties.ordered():
		var t: Treaty = s.treaties.get_or(tid)
		if t.def_id == def_id and ((t.a == a and t.b == b) or (t.a == b and t.b == a)):
			return true
	return false


func _cmd(s: MatchState, eid: int, type_id: StringName, payload: Dictionary) -> bool:
	return Sim.execute(s, [CommandRegistry.create(type_id, eid, payload)] as Array[Command]).is_empty()


func _sp(e: Empire) -> String:
	return "%s#%d" % [e.species.get_slice("/", 1), e.id] if e != null else "?"
