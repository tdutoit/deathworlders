class_name StockpileScreen
extends ScreenPanel
## Stockpile view (F9): every stockpile the player has (colonies and stations) with fill bars. Filters:
## one resource, or "near full" / "empty" (zero-stock rows for resources the holder can store).

const FILTERS: Array[String] = ["all", "near_full", "empty"]
const NEAR_FULL_PERMILLE := 900

var _resource := ""  # "" = every resource
var _filter := "all"


func _init() -> void:
	title_key = "STOCK_TITLE"


func _fill(state: MatchState, eid: int) -> void:
	var top := row()
	var items := [["STOCK_ALL_RESOURCES", ""]]
	var selected := 0
	for def in state.defs.defs("resource"):
		if (def as ResourceDef).physical:
			if String(def.id) == _resource:
				selected = items.size()
			items.append([def.name_key, String(def.id)])
	var opt := UiKit.options(items, selected)
	opt.name = "Resource"
	opt.item_selected.connect(func(i: int) -> void:
		_resource = opt.get_item_metadata(i)
		rebuild.call_deferred())
	top.add_child(opt)
	for f in FILTERS:
		var b := button(TranslationServer.translate("STOCK_FILTER_%s" % f.to_upper()), "Filter_" + f, func() -> void:
			_filter = f
			rebuild.call_deferred(), top)
		b.toggle_mode = true
		b.set_pressed_no_signal(f == _filter)
	var totals := {}
	var g := table(["STOCK_COL_HOLDER", "STOCK_COL_RES", "STOCK_COL_STOCK", "STOCK_COL_CAP", "STOCK_COL_FILL", "STOCK_COL_NET"])
	var rows := 0
	for h in AutoLogistics._own_holders(state, eid):
		var sp := Holders.stockpile(state, h)
		var c := state.colony(h)
		var keys: Array = sp.amounts.keys()
		if _filter == "empty" or _resource != "":
			for def in state.defs.defs("resource"):
				var id := String(def.id)
				if (def as ResourceDef).physical and not id in keys and Holders.cap_milli(state, h, id) > 0:
					keys.append(id)
		for res: String in IdMap.sort_keys(keys):
			if _resource != "" and res != _resource:
				continue
			var have := sp.milli(res)
			var cap := Holders.cap_milli(state, h, res)
			totals[res] = int(totals.get(res, 0)) + have
			if _filter == "near_full" and (cap <= 0 or have * 1000 < cap * NEAR_FULL_PERMILLE):
				continue
			if _filter == "empty" and have > 0:
				continue
			cell(g, UiNames.holder(state, h))
			cell(g, UiNames.def_name(res))
			cell(g, UiKit.units(have), "Mono")
			cell(g, UiKit.units(cap) if cap > 0 else "—", "Mono")
			cell(g, UiNames.bar(have, cap), "Mono")
			var net := "" if c == null else UiKit.signed(int(c.last_produced.get(res, 0)) - int(c.last_consumed.get(res, 0)))
			cell(g, net, "Mono")
			rows += 1
	if rows == 0:
		heading("STOCK_NOTHING")
	var parts := []
	for res: String in IdMap.sort_keys(totals.keys()):
		parts.append("%s %s" % [UiNames.def_name(res), UiKit.units(int(totals[res]))])
	line(UiKit.tr_fmt("STOCK_TOTALS", {"list": " · ".join(parts)}), "Caption")
