class_name LogisticsScreen
extends ScreenPanel
## Logistics Manager (F7): trunk routes, demand targets, hubs & freighters, convoy losses. One section is
## shown at a time (tab buttons at the top, keyboard-focusable). Delete/remove buttons submit Commands.

const TABS: Array[String] = ["routes", "demands", "hubs", "losses"]

var _tab := "routes"


func _init() -> void:
	title_key = "LOGI_TITLE"


func _fill(state: MatchState, eid: int) -> void:
	var tabs := row()
	for t in TABS:
		var b := button(TranslationServer.translate("LOGI_TAB_%s" % t.to_upper()), "Tab_" + t, func() -> void:
			_tab = t
			rebuild.call_deferred(), tabs)
		b.toggle_mode = true
		b.set_pressed_no_signal(t == _tab)
	match _tab:
		"routes":
			_routes(state, eid)
		"demands":
			_demands(state, eid)
		"hubs":
			_hubs(state, eid)
		"losses":
			_losses(state, eid)


## Trunk and local routes (B7) with their assigned freighters; the per-month throughput estimate needs
## the round-trip time, so M2 shows the per-trip amount and the freighters on it.
func _routes(state: MatchState, eid: int) -> void:
	var g := table(["LOGI_COL_FROM", "LOGI_COL_TO", "LOGI_COL_RES", "LOGI_COL_PER_TRIP", "LOGI_COL_PRIO", "LOGI_COL_FREIGHTERS", ""])
	var any := false
	for rid: int in state.routes:
		var r: Route = state.routes.get_or(rid)
		if r.owner != eid:
			continue
		any = true
		var assigned := 0
		for uid: int in state.units:
			if (state.units.get_or(uid) as Unit).route == r.id:
				assigned += 1
		cell(g, UiNames.holder(state, r.source))
		cell(g, UiNames.holder(state, r.dest))
		cell(g, UiNames.def_name(r.resource))
		cell(g, str(r.amount), "Mono")
		cell(g, UiNames.priority(r.priority), "Mono")
		cell(g, str(assigned), "Mono")
		button(TranslationServer.translate("LOGI_DELETE"), "DeleteRoute_%d" % r.id, func() -> void:
			CommandQueue.submit_new(CmdDeleteRoute.TYPE, {"route": r.id}), g)
	if not any:
		heading("LOGI_NO_ROUTES")


func _demands(state: MatchState, eid: int) -> void:
	var g := table(["LOGI_COL_HOLDER", "LOGI_COL_RES", "LOGI_COL_TARGET", "LOGI_COL_STOCK", "LOGI_COL_PRIO", ""])
	var any := false
	for did: int in state.demands:
		var d: Demand = state.demands.get_or(did)
		if d.owner != eid:
			continue
		any = true
		cell(g, UiNames.holder(state, d.holder))
		cell(g, UiNames.def_name(d.resource))
		cell(g, str(d.target), "Mono")
		cell(g, UiKit.units(Holders.stockpile(state, d.holder).milli(d.resource)), "Mono")
		cell(g, UiNames.priority(d.priority), "Mono")
		button(TranslationServer.translate("LOGI_REMOVE"), "RemoveDemand_%d" % d.id, func() -> void:
			CommandQueue.submit_new(CmdSetDemandTarget.TYPE, {"holder": d.holder, "resource": d.resource, "target": 0}), g)
	if not any:
		heading("LOGI_NO_DEMANDS")
	heading("LOGI_DEMANDS_NOTE")


## Every hub with berths, its freighters and what each is doing.
func _hubs(state: MatchState, eid: int) -> void:
	var any := false
	for h in AutoLogistics._own_holders(state, eid):
		var berths := Shipyards.berths(state, h)
		if berths <= 0:
			continue
		any = true
		line(UiKit.tr_fmt("LOGI_HUB", {"name": UiNames.holder(state, h), "used": Shipyards.berths_used(state, h),
			"berths": berths, "range": AutoLogistics.hub_range(state, h)}), "Subtitle")
		var g := table(["LOGI_COL_FREIGHTER", "LOGI_COL_AT", "LOGI_COL_JOB"])
		for uid: int in state.units:
			var u: Unit = state.units.get_or(uid)
			if u.kind != "freighter" or u.home != h:
				continue
			cell(g, UiNames.def_name(u.hull_id))
			cell(g, state.galaxy.system(u.system_id).name)
			var p := Freight.plan(state, u)
			if p.is_empty():
				cell(g, TranslationServer.translate("LOGI_IDLE"))
			else:
				cell(g, UiKit.tr_fmt("LOGI_JOB", {"amount": UiKit.units(int(p["amount"])), "res": UiNames.def_name(p["resource"]),
					"from": UiNames.holder(state, p["source"]), "to": UiNames.holder(state, p["dest"])}))
	if not any:
		heading("LOGI_NO_HUBS")


func _losses(state: MatchState, eid: int) -> void:
	var e := state.empire(eid)
	if e.losses.is_empty():
		heading("LOGI_NO_LOSSES")
		return
	var g := table(["LOGI_COL_DATE", "LOGI_COL_SYSTEM", "LOGI_COL_HULL", "LOGI_COL_CARGO"])
	for i in range(e.losses.size() - 1, -1, -1):
		var l: Dictionary = e.losses[i]
		cell(g, Calendar.format(int(l["tick"])), "Mono")
		cell(g, state.galaxy.system(int(l["system"])).name)
		cell(g, UiNames.def_name(l["hull"]))
		var cargo := []
		for res: String in IdMap.sort_keys(l["cargo"].keys()):
			cargo.append("%s %s" % [UiKit.units(int(l["cargo"][res])), UiNames.def_name(res)])
		cell(g, ", ".join(cargo) if not cargo.is_empty() else "—")
