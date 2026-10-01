class_name SectorScreen
extends ScreenPanel
## Sector screen (F6): each of the player's sectors with its hub, directive, planets, summed stockpile
## with last month's net and export quota, and freight use. Directive and quota changes submit Commands.

const QUOTA_STEP := 100  # permille per press


func _init() -> void:
	title_key = "SECTOR_TITLE"


func _fill(state: MatchState, eid: int) -> void:
	var any := false
	for sec_id: int in state.sectors:
		var sec: Sector = state.sectors.get_or(sec_id)
		if sec.owner == eid:
			any = true
			_sector(state, sec)
	if not any:
		heading("SECTOR_NONE")


func _sector(state: MatchState, sec: Sector) -> void:
	var r := Economy.rules(state.defs)
	var hub_name := UiNames.holder(state, sec.hub)
	line(UiKit.tr_fmt("SECTOR_HEADER_CORE" if sec.core else "SECTOR_HEADER", {"hub": hub_name}), "Subtitle")
	var top := row()
	line(TranslationServer.translate("SECTOR_DIRECTIVE"), "", top)
	var items := []
	var selected := 0
	for def in state.defs.defs("directive"):
		if String(def.id) == sec.directive:
			selected = items.size()
		items.append([def.name_key, String(def.id)])
	var opt := UiKit.options(items, selected)
	opt.name = "Directive_%d" % sec.id
	opt.item_selected.connect(func(i: int) -> void:
		CommandQueue.submit_new(CmdSetDirective.TYPE, {"sector": sec.id, "directive": opt.get_item_metadata(i)}))
	top.add_child(opt)
	var planets: Array[Colony] = []
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == sec.owner and state.galaxy.planet(pid).system_id in sec.systems:
			planets.append(c)
	line(UiKit.tr_fmt("SECTOR_COUNTS", {"systems": sec.systems.size(), "planets": planets.size()}), "Caption", top)
	var g := table(["SECTOR_COL_PLANET", "SECTOR_COL_STAGE", "SECTOR_COL_FOCUS", "SECTOR_COL_POPS", "SECTOR_COL_STAB",
		"SECTOR_COL_MODE"])
	for c in planets:
		cell(g, state.galaxy.planet(c.id).name)
		cell(g, TranslationServer.translate("STAGE_" + c.stage.to_upper()))
		cell(g, "—" if c.primary_focus == "" else UiNames.def_name(c.primary_focus))
		cell(g, str(c.total_pops()), "Mono")
		cell(g, str(c.stability), "Mono")
		cell(g, TranslationServer.translate("AUTONOMY_SHORT_%s" % c.autonomy.to_upper()))
	# Sector stockpile: colonies and stations in the sector, with the colonies' last-month net.
	var stock := {}
	var net := {}
	for h in _holders(state, sec):
		var sp := Holders.stockpile(state, h)
		for res: String in sp.amounts:
			stock[res] = int(stock.get(res, 0)) + sp.milli(res)
		var c := state.colony(h)
		if c != null:
			for res: String in c.last_produced:
				net[res] = int(net.get(res, 0)) + int(c.last_produced[res])
			for res: String in c.last_consumed:
				net[res] = int(net.get(res, 0)) - int(c.last_consumed[res])
	var sg := table(["SECTOR_COL_RES", "SECTOR_COL_STOCK", "SECTOR_COL_NET", "SECTOR_COL_EXPORT", "", ""])
	var keys := stock.keys()
	for res: String in net:
		if not res in keys and (state.defs.get_def(StringName(res)) as ResourceDef).physical:
			keys.append(res)
	for res: String in IdMap.sort_keys(keys):
		var quota := int(sec.export_quotas.get(res, r.export_quota_default_permille))
		cell(sg, UiNames.def_name(res))
		cell(sg, UiKit.units(int(stock.get(res, 0))), "Mono")
		cell(sg, UiKit.signed(int(net.get(res, 0))), "Mono")
		cell(sg, "—" if sec.core else "%d%%" % (quota / 10), "Mono")
		if sec.core:
			cell(sg, "")
			cell(sg, "")
			continue
		button("−", "QuotaDown_%d_%s" % [sec.id, res.get_slice("/", 1)], func() -> void:
			CommandQueue.submit_new(CmdSetExportQuota.TYPE, {"sector": sec.id, "resource": res, "permille": maxi(0, quota - QUOTA_STEP)}), sg)
		button("+", "QuotaUp_%d_%s" % [sec.id, res.get_slice("/", 1)], func() -> void:
			CommandQueue.submit_new(CmdSetExportQuota.TYPE, {"sector": sec.id, "resource": res, "permille": mini(1000, quota + QUOTA_STEP)}), sg)
	var berths := Shipyards.berths(state, sec.hub)
	var used := Shipyards.berths_used(state, sec.hub)
	var busy := 0
	var lost := 0
	for uid: int in state.units:
		var u: Unit = state.units.get_or(uid)
		if u.kind == "freighter" and u.home == sec.hub and not Freight.plan(state, u).is_empty():
			busy += 1
	for l: Dictionary in state.empire(sec.owner).losses:
		if int(l["system"]) in sec.systems:
			lost += 1
	line(UiKit.tr_fmt("SECTOR_FREIGHT", {"used": used, "berths": berths, "pct": busy * 100 / maxi(1, used), "lost": lost}))
	var alerts := 0
	for a: Dictionary in Alerts.collect(state, sec.owner):
		if a["kind"] == "planet" and state.galaxy.planet(a["id"]).system_id in sec.systems:
			alerts += 1
	line(UiKit.tr_fmt("SECTOR_ALERTS", {"n": alerts}), "Caption")
	_body.add_child(HSeparator.new())


static func _holders(state: MatchState, sec: Sector) -> Array[int]:
	var out: Array[int] = []
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == sec.owner and state.galaxy.planet(pid).system_id in sec.systems:
			out.append(pid)
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if s.owner == sec.owner and s.operational and s.system_id in sec.systems:
			out.append(sid)
	return out
