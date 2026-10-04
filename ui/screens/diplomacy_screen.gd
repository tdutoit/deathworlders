class_name DiplomacyScreen
extends ScreenPanel
## Diplomacy (F5; Sub-spec F14, M4 WP13). Tabs: Empires (opinion and trust breakdowns, treaties, claims, the
## proposal builder with deal items and the live E5 acceptance breakdown, war declaration), War (wars, war score,
## exhaustion, peace terms, war footing), Council (membership, session, resolutions, votes, proposals), Inbox
## (proposals, peace offers and calls to arms waiting for you). Reads state; every control submits a Command.

const TABS: Array[String] = ["empires", "war", "council", "inbox"]
const KINDS: Array[String] = ["credits", "influence", "resource", "system"]
const TRADE_RESOURCES: Array[String] = ["core:resource/food", "core:resource/ore", "core:resource/alloys",
	"core:resource/components", "core:resource/fuel", "core:resource/munitions", "core:resource/rare_earths",
	"core:resource/exotics"]

var _tab := "empires"
var _target := 0  # selected empire
var _treaty := ""  # proposal: treaty Def ID or "" (deal only)
var _items: Array = []  # proposal deal items
var _cb := ""
var _terms := {}  # war tab: enemy -> [terms]


func _init() -> void:
	title_key = "DIPLO_TITLE"


func open() -> void:
	super.open()
	var vp := get_viewport_rect().size
	custom_minimum_size = Vector2(vp.x - 48.0, vp.y - 150.0)
	size = custom_minimum_size
	position = Vector2(24.0, 96.0)


func _fill(state: MatchState, eid: int) -> void:
	_header(state, eid)
	var tabs := row()
	for t in TABS:
		var label := TranslationServer.translate("DIPLO_TAB_%s" % t.to_upper())
		if t == "inbox":
			label = UiKit.tr_fmt("DIPLO_TAB_INBOX_N", {"n": inbox_count(state, eid)})
		var b := button(label, "Tab_" + t, func() -> void:
			_tab = t
			rebuild.call_deferred(), tabs)
		b.toggle_mode = true
		b.set_pressed_no_signal(t == _tab)
	match _tab:
		"empires":
			_empires(state, eid)
		"war":
			_wars(state, eid)
		"council":
			_council(state, eid)
		"inbox":
			_inbox(state, eid)


## Your signature meter, Reputation and war footing, with the signature action where there is one.
func _header(state: MatchState, eid: int) -> void:
	var e := state.empire(eid)
	var r := row()
	var mech := SignatureMechanics.of(state, e)
	var parts := []
	if mech != null:
		var m := mech.meter(state, e)
		for k: String in IdMap.sort_keys(m.keys()):
			parts.append("%s %d" % [TranslationServer.translate(k), int(m[k])])
	parts.append(UiKit.tr_fmt("DIPLO_REPUTATION", {"n": e.reputation}))
	parts.append(UiKit.tr_fmt("DIPLO_EXHAUSTION", {"n": e.war_exhaustion / 1000}))
	line("  ·  ".join(parts), "Mono", r)
	if mech is ContractsMechanic:
		button(TranslationServer.translate("DIPLO_HIRE_MERCS"), "HireMercs", func() -> void:
			CommandQueue.submit_new(CmdHireMercenaries.TYPE, {}), r)


static func inbox_count(state: MatchState, eid: int) -> int:
	var n := 0
	for pid: int in state.proposals.ordered():
		n += 1 if (state.proposals.get_or(pid) as Proposal).to == eid else 0
	for pid: int in state.peace_offers.ordered():
		n += 1 if (state.peace_offers.get_or(pid) as PeaceOffer).to == eid else 0
	for cid: int in state.calls.ordered():
		n += 1 if (state.calls.get_or(cid) as CallToArms).to == eid else 0
	return n


# --- Empires ---

func _empires(state: MatchState, eid: int) -> void:
	var contacts: Array[int] = []
	for other: int in state.empires.ordered():
		if other != eid and Relations.has_contact(state, eid, other):
			contacts.append(other)
	if contacts.is_empty():
		heading("DIPLO_NO_CONTACT")
		return
	if not _target in contacts:
		_target = contacts[0]
	var list := row()
	for other in contacts:
		var b := button("%s %+d" % [UiNames.owner(state, other), Relations.opinion(state, other, eid)], "Emp_%d" % other,
			func() -> void:
				_target = other
				_items = []
				rebuild.call_deferred(), list)
		b.toggle_mode = true
		b.set_pressed_no_signal(other == _target)
	var t := _target
	var sd := state.defs.get_def(StringName(state.empire(t).species)) as SpeciesDef
	line(UiKit.tr_fmt("DIPLO_EMPIRE_HEADER", {"name": UiNames.owner(state, t),
		"personality": TranslationServer.translate(sd.personality_key) if sd else "",
		"opinion": Relations.opinion(state, t, eid), "trust": Relations.trust(state, t, eid),
		"mine": Relations.opinion(state, eid, t), "power": Treaties.power(state, t), "power_mine": Treaties.power(state, eid)}), "Subtitle")
	var parts := []
	for p: Array in Relations.breakdown(state, t, eid):
		if int(p[1]) != 0 or p[0] == "OPINION_AFFINITY":
			parts.append("%s %+d" % [TranslationServer.translate(p[0]), int(p[1])])
	line(TranslationServer.translate("DIPLO_THEIR_VIEW") + ": " + ", ".join(parts), "Caption")
	_treaties(state, eid, t)
	_proposal(state, eid, t)
	_claims_and_war(state, eid, t)


func _treaties(state: MatchState, eid: int, t: int) -> void:
	heading("DIPLO_TREATIES")
	var active := Treaties.between(state, eid, t)
	if active.is_empty():
		line(TranslationServer.translate("DIPLO_NONE"), "Caption")
	for tr in active:
		var d := Treaties.def_of(state, tr.def_id)
		var r := row()
		var age_years := FixedMath.floor_div(state.tick - tr.start_tick, Calendar.HOURS_PER_YEAR)
		var status := UiKit.tr_fmt("DIPLO_TREATY_AGE", {"years": age_years, "min": d.min_years})
		if tr.ends_tick > 0:
			status = UiKit.tr_fmt("DIPLO_TREATY_ENDS", {"date": Calendar.format(tr.ends_tick)})
		line("%s · %s" % [TranslationServer.translate(d.name_key), status], "", r)
		var early := age_years < d.min_years
		button(TranslationServer.translate("DIPLO_BREAK" if early else "DIPLO_CANCEL"), "Cancel_%d" % tr.id, func() -> void:
			CommandQueue.submit_new(CmdCancelTreaty.TYPE, {"treaty": tr.id}), r)


## The proposal builder: a treaty and/or deal items, with the live E5 acceptance breakdown.
func _proposal(state: MatchState, eid: int, t: int) -> void:
	heading("DIPLO_PROPOSE")
	var r := row()
	var items := [["DIPLO_DEAL_ONLY", ""]]
	var sel := 0
	for def in state.defs.defs("treaty"):
		var d: TreatyDef = def
		if Treaties.check_propose(state, eid, t, String(d.id)) == "":
			if String(d.id) == _treaty:
				sel = items.size()
			items.append([d.name_key, String(d.id)])
	if sel == 0:
		_treaty = ""
	var opt := UiKit.options(items, sel)
	opt.name = "Treaty"
	opt.item_selected.connect(func(i: int) -> void:
		_treaty = String(opt.get_item_metadata(i))
		rebuild.call_deferred())
	r.add_child(opt)
	button(TranslationServer.translate("DIPLO_ADD_GIVE"), "AddGive", func() -> void:
		_items.append({"giver": eid, "kind": "credits", "ref": "", "amount": 50, "months": 0})
		rebuild.call_deferred(), r)
	button(TranslationServer.translate("DIPLO_ADD_ASK"), "AddAsk", func() -> void:
		_items.append({"giver": t, "kind": "credits", "ref": "", "amount": 50, "months": 0})
		rebuild.call_deferred(), r)
	for i in _items.size():
		_item_row(state, eid, t, i)
	if _treaty == "" and _items.is_empty():
		return
	var acc := Treaties.acceptance(state, eid, t, _treaty, _items)
	var parts := []
	for p: Array in acc["parts"]:
		parts.append("%s %+d" % [TranslationServer.translate(p[0]), int(p[1])])
	var verdict := "DIPLO_WOULD_ACCEPT" if acc["blocked"] == "" and int(acc["total"]) >= 0 else "DIPLO_WOULD_REFUSE"
	if _treaty == "" and Deals.is_gift(_items, eid):
		verdict = "DIPLO_WOULD_ACCEPT"
	line(UiKit.tr_fmt("DIPLO_ACCEPTANCE", {"total": acc["total"], "parts": ", ".join(parts)}), "Mono")
	if acc["blocked"] != "":
		line(TranslationServer.translate(acc["blocked"]), "Caption")
	line(TranslationServer.translate(verdict), "Caption")
	var problem := Deals.check(state, eid, t, _items, _treaty != "" and Treaties.def_of(state, _treaty).has("trade")) if not _items.is_empty() else ""
	if problem != "":
		line(UiKit.tr_fmt("DIPLO_DEAL_PROBLEM", {"why": problem}), "Caption")
		return
	button(TranslationServer.translate("DIPLO_SEND"), "Send", func() -> void:
		if _items.is_empty():
			CommandQueue.submit_new(CmdProposeTreaty.TYPE, {"to": t, "treaty": _treaty})
		else:
			CommandQueue.submit_new(CmdProposeDeal.TYPE, {"to": t, "treaty": _treaty, "items": _items.duplicate(true)})
		_items = []
		_treaty = ""
		rebuild.call_deferred())


func _item_row(state: MatchState, eid: int, t: int, i: int) -> void:
	var it: Dictionary = _items[i]
	var r := row()
	line(TranslationServer.translate("DIPLO_YOU_GIVE" if int(it["giver"]) == eid else "DIPLO_THEY_GIVE"), "Caption", r)
	var kinds := []
	for k in KINDS:
		kinds.append(["DIPLO_KIND_%s" % k.to_upper(), k])
	var kopt := UiKit.options(kinds, KINDS.find(String(it["kind"])))
	kopt.name = "Kind_%d" % i
	kopt.item_selected.connect(func(k: int) -> void:
		it["kind"] = String(kopt.get_item_metadata(k))
		it["ref"] = TRADE_RESOURCES[0] if it["kind"] == "resource" else ""
		it["amount"] = 1 if it["kind"] == "system" else 50
		rebuild.call_deferred())
	r.add_child(kopt)
	if it["kind"] == "resource":
		var res := []
		for rid in TRADE_RESOURCES:
			res.append([UiNames.def_name(rid), rid])
		var ropt := UiKit.options(res, maxi(0, TRADE_RESOURCES.find(String(it["ref"]))))
		ropt.name = "Res_%d" % i
		ropt.item_selected.connect(func(k: int) -> void:
			it["ref"] = String(ropt.get_item_metadata(k))
			rebuild.call_deferred())
		r.add_child(ropt)
	elif it["kind"] == "system":
		var giver := int(it["giver"])
		var cap := state.galaxy.planet(state.empire(giver).capital_planet).system_id
		var systems := []
		var ssel := 0
		for sid: int in state.galaxy.systems.ordered():
			if state.galaxy.system(sid).owner == giver and sid != cap:
				if str(sid) == str(it["ref"]):
					ssel = systems.size()
				systems.append([state.galaxy.system(sid).name, str(sid)])
		if systems.is_empty():
			line(TranslationServer.translate("DIPLO_NO_SYSTEMS"), "Caption", r)
		else:
			if str(it["ref"]) == "":
				it["ref"] = systems[0][1]
			var sopt := UiKit.options(systems, ssel)
			sopt.name = "Sys_%d" % i
			sopt.item_selected.connect(func(k: int) -> void:
				it["ref"] = String(sopt.get_item_metadata(k))
				rebuild.call_deferred())
			r.add_child(sopt)
	if it["kind"] != "system":
		_number(r, "Amount_%d" % i, int(it["amount"]), "DIPLO_AMOUNT", func(v: int) -> void: it["amount"] = maxi(1, v))
		_number(r, "Months_%d" % i, int(it["months"]), "DIPLO_MONTHS", func(v: int) -> void: it["months"] = maxi(0, v))
	button(TranslationServer.translate("DIPLO_REMOVE"), "Remove_%d" % i, func() -> void:
		_items.remove_at(i)
		rebuild.call_deferred(), r)


func _number(parent: Control, node_name: String, value: int, hint_key: String, on_set: Callable) -> void:
	var le := LineEdit.new()
	le.name = node_name
	le.text = str(value)
	le.tooltip_text = TranslationServer.translate(hint_key)
	le.custom_minimum_size.x = 70
	le.text_submitted.connect(func(text: String) -> void:
		on_set.call(int(text) if text.is_valid_int() else 0)
		rebuild.call_deferred())
	parent.add_child(le)


func _claims_and_war(state: MatchState, eid: int, t: int) -> void:
	heading("DIPLO_CLAIMS")
	var r := row()
	var shown := 0
	for sid: int in state.galaxy.systems.ordered():
		if state.galaxy.system(sid).owner != t or shown >= 8:
			continue
		shown += 1
		var claimed := Wars.has_claim(state, eid, sid)
		var b := button(("✓ " if claimed else "") + state.galaxy.system(sid).name, "Claim_%d" % sid, func() -> void:
			CommandQueue.submit_new(CmdClaimSystem.TYPE, {"system": sid}), r)
		b.disabled = claimed
	if state.wars.has(Battles.war_key(eid, t)):
		return
	heading("DIPLO_WAR")
	var w := row()
	var cbs := Wars.casus_belli(state, eid, t)
	var items := [["DIPLO_NO_CB", ""]]
	for cb in cbs:
		items.append(["CB_%s" % cb.to_upper(), cb])
	if not _cb in cbs:
		_cb = ""
	var opt := UiKit.options(items, maxi(0, cbs.find(_cb) + 1) if _cb != "" else 0)
	opt.name = "CB"
	opt.item_selected.connect(func(i: int) -> void: _cb = String(opt.get_item_metadata(i)))
	w.add_child(opt)
	var reason := Treaties.check_war(state, eid, t)
	var b := button(TranslationServer.translate("DIPLO_DECLARE"), "Declare", func() -> void:
		CommandQueue.submit_new(CmdDeclareWar.TYPE, {"empire": t, "casus_belli": _cb}), w)
	b.disabled = reason != ""
	if reason != "":
		line(reason, "Caption", w)
	if _cb == "":
		line(TranslationServer.translate("DIPLO_NO_CB_WARNING"), "Caption")


# --- War ---

func _wars(state: MatchState, eid: int) -> void:
	var fr := row()
	line(TranslationServer.translate("DIPLO_FOOTING"), "Caption", fr)
	var footings: Array = state.defs.defs("war_footing")
	footings.sort_custom(func(a: WarFootingDef, b: WarFootingDef) -> bool: return a.order < b.order)
	var items := []
	var sel := 0
	for f: WarFootingDef in footings:
		if String(f.id) == state.empire(eid).footing:
			sel = items.size()
		items.append([f.name_key, String(f.id)])
	var fopt := UiKit.options(items, sel)
	fopt.name = "Footing"
	fopt.item_selected.connect(func(i: int) -> void:
		CommandQueue.submit_new(CmdSetWarFooting.TYPE, {"footing": fopt.get_item_metadata(i)}))
	fr.add_child(fopt)
	var any := false
	for wid: int in state.war_info.ordered():
		var w: War = state.war_info.get_or(wid)
		if w.attacker != eid and w.defender != eid:
			continue
		any = true
		var enemy := w.defender if w.attacker == eid else w.attacker
		line(UiKit.tr_fmt("DIPLO_WAR_LINE", {"enemy": UiNames.owner(state, enemy), "score": w.score_of(eid),
			"cb": TranslationServer.translate("CB_%s" % (w.casus_belli if w.casus_belli != "" else "none").to_upper()),
			"mine": state.empire(eid).war_exhaustion / 1000, "theirs": state.empire(enemy).war_exhaustion / 1000}), "Subtitle")
		_peace_builder(state, eid, w, enemy)
	if not any:
		heading("DIPLO_NO_WARS")


func _peace_builder(state: MatchState, eid: int, w: War, enemy: int) -> void:
	var terms: Array = _terms.get(enemy, [])
	var r := row()
	for term in Wars.allowed_terms(state, w, eid):
		if term == "white":
			continue
		if term == "cede_system":
			for sid in Wars.claims_on(state, eid, enemy):
				var on := terms.any(func(x: Dictionary) -> bool: return x["type"] == "cede_system" and int(x["ref"]) == sid)
				var cb := CheckBox.new()
				cb.name = "Cede_%d" % sid
				cb.text = UiKit.tr_fmt("DIPLO_TERM_CEDE", {"system": state.galaxy.system(sid).name})
				cb.button_pressed = on
				cb.focus_mode = Control.FOCUS_ALL
				cb.toggled.connect(func(p: bool) -> void:
					terms = terms.filter(func(x: Dictionary) -> bool: return not (x["type"] == "cede_system" and int(x["ref"]) == sid))
					if p:
						terms.append({"type": "cede_system", "ref": sid})
					_terms[enemy] = terms
					rebuild.call_deferred())
				r.add_child(cb)
			continue
		var has := terms.any(func(x: Dictionary) -> bool: return x["type"] == term)
		var c := CheckBox.new()
		c.name = "Term_%s" % term
		c.text = TranslationServer.translate("DIPLO_TERM_%s" % term.to_upper())
		c.button_pressed = has
		c.focus_mode = Control.FOCUS_ALL
		c.toggled.connect(func(p: bool) -> void:
			terms = terms.filter(func(x: Dictionary) -> bool: return x["type"] != term)
			if p:
				terms.append({"type": term, "amount": 1000} if term == "reparations" else {"type": term})
			_terms[enemy] = terms
			rebuild.call_deferred())
		r.add_child(c)
	var cost := Wars.terms_cost(state, terms)
	var limit := w.score_of(eid) + FixedMath.floor_div(state.empire(enemy).war_exhaustion - state.empire(eid).war_exhaustion, 2000) \
		+ SignatureMechanics.peace_discount(state, eid)
	line(UiKit.tr_fmt("DIPLO_TERMS_COST", {"cost": cost, "limit": maxi(0, limit)}), "Mono")
	var p := row()
	button(TranslationServer.translate("DIPLO_DEMAND"), "Demand_%d" % enemy, func() -> void:
		CommandQueue.submit_new(CmdOfferPeace.TYPE, {"empire": enemy, "loser": enemy, "terms": terms.duplicate(true)}), p)
	button(TranslationServer.translate("DIPLO_WHITE_PEACE"), "White_%d" % enemy, func() -> void:
		CommandQueue.submit_new(CmdOfferPeace.TYPE, {"empire": enemy, "loser": eid, "terms": [{"type": "white"}]}), p)


# --- Council ---

func _council(state: MatchState, eid: int) -> void:
	var c := state.council
	if c == null:
		heading("DIPLO_NO_COUNCIL")
		return
	var member := eid in c.members
	line(UiKit.tr_fmt("DIPLO_COUNCIL_HEADER", {"members": ", ".join(c.members.map(func(m: int) -> String: return UiNames.owner(state, m))),
		"date": Calendar.format(c.next_session), "votes": Councils.votes(state, eid) if member else 0}), "Subtitle")
	if not member:
		line(TranslationServer.translate("DIPLO_NOT_MEMBER"), "Caption")
		if Councils.check_propose(state, eid, "core:resolution/recognition", eid, -1) == "":
			button(TranslationServer.translate("DIPLO_APPLY"), "ApplyRecognition", func() -> void:
				CommandQueue.submit_new(CmdCouncilPropose.TYPE, {"resolution": "core:resolution/recognition", "target": eid, "repeal": -1}))
	heading("DIPLO_RESOLUTIONS")
	if c.active.is_empty():
		line(TranslationServer.translate("DIPLO_NONE"), "Caption")
	for a: Dictionary in c.active:
		var r := row()
		line(_resolution_name(state, a["def"], int(a["target"])), "", r)
		if member:
			button(TranslationServer.translate("DIPLO_REPEAL"), "Repeal_%d" % int(a["id"]), func() -> void:
				CommandQueue.submit_new(CmdCouncilPropose.TYPE, {"repeal": int(a["id"]), "target": -1}), r)
	heading("DIPLO_PROPOSALS")
	for p: Dictionary in c.proposals:
		var r := row()
		var label := _resolution_name(state, p["def"], int(p["target"])) if int(p["repeal"]) < 0 else UiKit.tr_fmt("DIPLO_REPEAL_OF", {"id": p["repeal"]})
		line(UiKit.tr_fmt("DIPLO_PROPOSAL_BY", {"what": label, "by": UiNames.owner(state, int(p["proposer"]))}), "", r)
		if member:
			var mine := int(p["votes"].get(str(eid), 0))
			for v: int in [1, -1, 0]:
				var b := button(TranslationServer.translate("DIPLO_VOTE_%d" % (v + 1)), "Vote_%d_%d" % [int(p["id"]), v + 1], func() -> void:
					CommandQueue.submit_new(CmdCouncilVote.TYPE, {"proposal": int(p["id"]), "vote": v}), r)
				b.toggle_mode = true
				b.set_pressed_no_signal(mine == v)
			if SignatureMechanics.of(state, state.empire(eid)) is PrecedenceMechanic:
				button(TranslationServer.translate("DIPLO_VETO"), "Veto_%d" % int(p["id"]), func() -> void:
					CommandQueue.submit_new(CmdPrecedenceVeto.TYPE, {"proposal": int(p["id"])}), r)
	if member:
		var r := row()
		for def in state.defs.defs("resolution"):
			var d: ResolutionDef = def
			if d.needs_target:
				for other: int in state.empires.ordered():
					if other != eid and Councils.check_propose(state, eid, String(d.id), other, -1) == "":
						button(UiKit.tr_fmt("DIPLO_PROPOSE_ON", {"what": TranslationServer.translate(d.name_key), "target": UiNames.owner(state, other)}),
							"Prop_%s_%d" % [String(d.id).get_slice("/", 1), other], func() -> void:
								CommandQueue.submit_new(CmdCouncilPropose.TYPE, {"resolution": String(d.id), "target": other, "repeal": -1}), r)
			elif Councils.check_propose(state, eid, String(d.id), -1, -1) == "":
				button(TranslationServer.translate(d.name_key), "Prop_%s" % String(d.id).get_slice("/", 1), func() -> void:
					CommandQueue.submit_new(CmdCouncilPropose.TYPE, {"resolution": String(d.id), "target": -1, "repeal": -1}), r)
	if not c.last_session.is_empty():
		heading("DIPLO_LAST_SESSION")
		for x: Dictionary in c.last_session:
			line(UiKit.tr_fmt("DIPLO_SESSION_LINE", {"what": _resolution_name(state, x["def"], int(x["target"])),
				"yes": x["yes"], "no": x["no"],
				"result": TranslationServer.translate("DIPLO_VETOED" if x["vetoed"] else ("DIPLO_PASSED" if x["passed"] else "DIPLO_FAILED"))}), "Caption")


func _resolution_name(state: MatchState, def_id: String, target: int) -> String:
	var d := Councils.def_of(state, def_id)
	var n: String = TranslationServer.translate(d.name_key) if d else def_id
	return "%s: %s" % [n, UiNames.owner(state, target)] if target >= 0 else n


# --- Inbox ---

func _inbox(state: MatchState, eid: int) -> void:
	var any := false
	for pid: int in state.proposals.ordered():
		var p: Proposal = state.proposals.get_or(pid)
		if p.to != eid:
			continue
		any = true
		var r := row()
		var what := TranslationServer.translate(Treaties.def_of(state, p.def_id).name_key) if p.def_id != "" else TranslationServer.translate("DIPLO_DEAL")
		line(UiKit.tr_fmt("DIPLO_PROPOSAL_FROM", {"what": what, "from": UiNames.owner(state, p.from), "items": p.items.size()}), "", r)
		button(TranslationServer.translate("DIPLO_ACCEPT"), "Accept_%d" % p.id, func() -> void:
			CommandQueue.submit_new(CmdAnswerProposal.TYPE, {"proposal": p.id, "accept": 1}), r)
		button(TranslationServer.translate("DIPLO_DECLINE"), "Decline_%d" % p.id, func() -> void:
			CommandQueue.submit_new(CmdAnswerProposal.TYPE, {"proposal": p.id, "accept": 0}), r)
	for oid: int in state.peace_offers.ordered():
		var o: PeaceOffer = state.peace_offers.get_or(oid)
		if o.to != eid:
			continue
		any = true
		var r := row()
		var terms := ", ".join(o.terms.map(func(x: Dictionary) -> String: return TranslationServer.translate("DIPLO_TERM_%s" % String(x["type"]).to_upper())))
		line(UiKit.tr_fmt("DIPLO_PEACE_FROM", {"from": UiNames.owner(state, o.from), "loser": UiNames.owner(state, o.loser), "terms": terms}), "", r)
		button(TranslationServer.translate("DIPLO_ACCEPT"), "AcceptPeace_%d" % o.id, func() -> void:
			CommandQueue.submit_new(CmdAnswerPeace.TYPE, {"offer": o.id, "accept": 1}), r)
		button(TranslationServer.translate("DIPLO_DECLINE"), "DeclinePeace_%d" % o.id, func() -> void:
			CommandQueue.submit_new(CmdAnswerPeace.TYPE, {"offer": o.id, "accept": 0}), r)
	for cid: int in state.calls.ordered():
		var c: CallToArms = state.calls.get_or(cid)
		if c.to != eid:
			continue
		any = true
		var r := row()
		line(UiKit.tr_fmt("DIPLO_CALL_FROM", {"from": UiNames.owner(state, c.from), "enemy": UiNames.owner(state, c.enemy),
			"date": Calendar.format(c.deadline_tick)}), "", r)
		button(TranslationServer.translate("DIPLO_JOIN"), "Join_%d" % c.id, func() -> void:
			CommandQueue.submit_new(CmdAnswerCall.TYPE, {"call": c.id, "join": 1}), r)
		button(TranslationServer.translate("DIPLO_REFUSE"), "Refuse_%d" % c.id, func() -> void:
			CommandQueue.submit_new(CmdAnswerCall.TYPE, {"call": c.id, "join": 0}), r)
	if not any:
		heading("DIPLO_INBOX_EMPTY")
