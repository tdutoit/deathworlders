class_name BattlesScreen
extends ScreenPanel
## Battle Reports (F4; Sub-spec F11): the match's archive of battles the player fought, newest first, and
## the selected report: header and results, strength over time with range phases, losses by class, the
## matchup by weapon family and point defence, generated key moments, and honours (MVP by damage).
## Read-only.

const BLOCKS := "▁▂▃▄▅▆▇█"
const CHART_WIDTH := 40
const LIST_MAX := 12

var _report := 0  # selected report ID (0 = newest)


func _init() -> void:
	title_key = "BATTLES_TITLE"


func _fill(state: MatchState, eid: int) -> void:
	var mine: Array[BattleReport] = []
	for rid: int in state.reports.ordered():
		var rep: BattleReport = state.reports.get_or(rid)
		if eid in rep.data["owners"]:
			mine.append(rep)
	if mine.is_empty():
		heading("BATTLES_NONE")
		return
	mine.reverse()
	var shown: BattleReport = mine[0]
	for rep in mine:
		if rep.id == _report:
			shown = rep
	var list := row()
	for i in mini(mine.size(), LIST_MAX):
		var rep := mine[i]
		var b := button(_title_of(state, rep, eid), "Report_%d" % rep.id, func() -> void:
			_report = rep.id
			rebuild.call_deferred(), list)
		b.toggle_mode = true
		b.set_pressed_no_signal(rep == shown)
	if mine.size() > LIST_MAX:
		line(UiKit.tr_fmt("BATTLES_MORE", {"n": mine.size() - LIST_MAX}), "Caption", list)
	_detail(state, shown, eid)


func _title_of(state: MatchState, rep: BattleReport, eid: int) -> String:
	var side: int = (rep.data["owners"] as Array).find(eid)
	return "%s · %s" % [state.galaxy.system(int(rep.data["system"])).name,
		TranslationServer.translate("RESULT_" + String(rep.data["results"][side]).to_upper())]


func _detail(state: MatchState, rep: BattleReport, eid: int) -> void:
	var d := rep.data
	var owners: Array = d["owners"]
	var side := owners.find(eid)
	var other := 1 - side
	line(UiKit.tr_fmt("BATTLES_HEADER", {"system": state.galaxy.system(int(d["system"])).name,
		"date": Calendar.format(int(d["start_tick"])),
		"result": TranslationServer.translate("RESULT_" + String(d["results"][side]).to_upper())}), "Subtitle")
	line(UiKit.tr_fmt("BATTLES_SIDES", {"a": UiNames.owner(state, owners[side]), "b": UiNames.owner(state, owners[other]),
		"rounds": d["rounds"], "a_cost": d["start_cost"][side], "b_cost": d["start_cost"][other]}))
	# Strength over time (hull per round), with range phases.
	heading("BATTLES_STRENGTH")
	var strength: Array = d["strength"]
	var top := 1
	for s: Array in strength:
		top = maxi(top, maxi(int(s[0]), int(s[1])))
	line("%s  %s" % [_spark(strength, side, top), UiNames.owner(state, owners[side])], "Mono")
	line("%s  %s" % [_spark(strength, other, top), UiNames.owner(state, owners[other])], "Mono")
	var bands: Array = d.get("bands", [])
	if not bands.is_empty():
		line("%s  %s" % [_phases(bands), TranslationServer.translate("BATTLES_PHASES")], "Mono")
	# Losses by class.
	heading("BATTLES_LOSSES")
	for s in [side, other]:
		line("%s: %s" % [UiNames.owner(state, owners[s]), _losses(d, s)])
	if int(d["salvage"][side]) > 0:
		line(UiKit.tr_fmt("BATTLES_SALVAGE", {"n": d["salvage"][side]}))
	# What worked: weapon families and point defence.
	heading("BATTLES_MATCHUP")
	var g := table(["BATTLES_COL_SIDE", "BATTLES_COL_FAMILY", "BATTLES_COL_SHOTS", "BATTLES_COL_HITS",
		"BATTLES_COL_INTERCEPTED", "BATTLES_COL_DAMAGE"])
	for s in [side, other]:
		var fam: Dictionary = d["family"][s]
		for fk: String in IdMap.sort_keys(fam.keys()):
			var v: Array = fam[fk]
			cell(g, UiNames.owner(state, owners[s]))
			cell(g, UiNames.def_name(fk))
			cell(g, str(v[0]), "Mono")
			cell(g, "%d%%" % (int(v[1]) * 100 / maxi(1, int(v[0]))), "Mono")
			cell(g, "%d%%" % (int(v[2]) * 100 / maxi(1, int(v[0]))), "Mono")
			cell(g, str(v[3]), "Mono")
	# Key moments and honours.
	heading("BATTLES_MOMENTS")
	for m in moments(d, side):
		line("• " + UiKit.tr_fmt(m[0], m[1]))
	var mvp := mvp_of(d, eid)
	if mvp != "":
		var n: Array = d["names"][mvp]
		line(UiKit.tr_fmt("BATTLES_MVP", {"ship": TranslationServer.translate(String(n[2])),
			"cls": TranslationServer.translate("CLASS_" + String(n[1]).to_upper()), "dmg": d["dmg"][mvp],
			"kills": int(d["kills"].get(mvp, 0))}), "Subtitle")


func _spark(strength: Array, side: int, top: int) -> String:
	var out := ""
	var n := strength.size()
	for i in mini(n, CHART_WIDTH):
		var s: Array = strength[i * n / mini(n, CHART_WIDTH)]
		var v := int(s[side])
		out += " " if v <= 0 else BLOCKS[clampi(v * BLOCKS.length() / (top + 1), 0, BLOCKS.length() - 1)]
	return out


## One letter per chart column: L(ong), M(edium), C(lose).
func _phases(bands: Array) -> String:
	var out := ""
	var n := bands.size()
	for i in mini(n, CHART_WIDTH):
		out += "LMC"[clampi(int(bands[i * n / mini(n, CHART_WIDTH)]), 0, 2)]
	return out


static func _losses(d: Dictionary, side: int) -> String:
	var by := {}
	for l: Array in d["lost"]:
		if int(l[0]) == side:
			by[String(l[2])] = int(by.get(String(l[2]), 0)) + 1
	for c: Array in d["captured"]:
		if int(c[0]) == side:
			var k := String(c[2]) + "*"
			by[k] = int(by.get(k, 0)) + 1
	if by.is_empty():
		return TranslationServer.translate("BATTLES_NO_LOSSES")
	var parts: Array[String] = []
	for k: String in IdMap.sort_keys(by.keys()):
		var captured := k.ends_with("*")
		var cls := TranslationServer.translate("CLASS_" + k.trim_suffix("*").to_upper())
		parts.append(UiKit.tr_fmt("BATTLES_CAPTURED_N" if captured else "BATTLES_LOST_N", {"n": by[k], "cls": cls}))
	return ", ".join(parts)


## Generated key moments as [loc key, params] (F11): first blood, range changes, captures, retreats.
static func moments(d: Dictionary, side: int) -> Array:
	var out := []
	var lost: Array = d["lost"]
	if not lost.is_empty():
		var first: Array = lost[0]
		out.append(["MOMENT_FIRST_LOSS_OURS" if int(first[0]) == side else "MOMENT_FIRST_LOSS_THEIRS",
			{"round": first[4], "cls": TranslationServer.translate("CLASS_" + String(first[2]).to_upper())}])
	var bands: Array = d.get("bands", [])
	for i in range(1, bands.size()):
		if int(bands[i]) != int(bands[i - 1]):
			out.append(["MOMENT_RANGE_%d" % clampi(int(bands[i]), 0, 2), {"round": i + 1}])
	for c: Array in d["captured"]:
		out.append(["MOMENT_CAPTURE_OURS" if int(c[0]) != side else "MOMENT_CAPTURE_THEIRS",
			{"round": c[4], "cls": TranslationServer.translate("CLASS_" + String(c[2]).to_upper())}])
	for r: Array in d["retreated"]:
		out.append(["MOMENT_RETREAT_OURS" if int(r[0]) == side else "MOMENT_RETREAT_THEIRS", {"round": r[2], "n": r[1]}])
	if d.has("truce"):
		out.append(["MOMENT_TRUCE", {}])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1].get("round", 999)) < int(b[1].get("round", 999)))
	return out


## The player's combatant that did the most hull damage ("" if none).
static func mvp_of(d: Dictionary, eid: int) -> String:
	var best := ""
	for cid: String in IdMap.sort_keys(d["dmg"].keys()):
		var n: Variant = d["names"].get(cid)
		if n == null or int(n[0]) != eid:
			continue
		if best == "" or int(d["dmg"][cid]) > int(d["dmg"][best]):
			best = cid
	return best
