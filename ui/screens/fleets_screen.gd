class_name FleetsScreen
extends ScreenPanel
## Fleets (F2; Sub-spec F5, owner decision 2026-10-02: a screen plus the context panel). Each own fleet with
## strength, condition, supply, doctrine and composition by task force, and its orders: patrol, escort,
## merge, split, rename (moves: right-click on the map with a warship selected). The Empires tab holds the
## M3 war toggle until M4 diplomacy. Every control submits a Command.

const TABS: Array[String] = ["fleets", "empires"]
const PATROL_LANES := 2  # "Patrol nearby": own systems within this many lanes

var _tab := "fleets"
var only_fleet := 0  # set by the context panel's "Open in Fleets" to show one fleet first


func _init() -> void:
	title_key = "FLEETS_TITLE"


func _fill(state: MatchState, eid: int) -> void:
	var tabs := row()
	for t in TABS:
		var b := button(TranslationServer.translate("FLEETS_TAB_%s" % t.to_upper()), "Tab_" + t, func() -> void:
			_tab = t
			rebuild.call_deferred(), tabs)
		b.toggle_mode = true
		b.set_pressed_no_signal(t == _tab)
	if _tab == "empires":
		_empires(state, eid)
		return
	var fleets: Array[Fleet] = []
	for fid: int in state.fleets.ordered():
		var f: Fleet = state.fleets.get_or(fid)
		if f.owner == eid:
			fleets.append(f)
	if fleets.is_empty():
		heading("FLEETS_NONE")
		return
	fleets.sort_custom(func(a: Fleet, b: Fleet) -> bool:
		return (a.id == only_fleet and b.id != only_fleet) or ((a.id == only_fleet) == (b.id == only_fleet) and a.id < b.id))
	for f in fleets:
		_fleet(state, eid, f)


func _fleet(state: MatchState, eid: int, f: Fleet) -> void:
	line(UiFleets.name_of(state, f), "Subtitle")
	var c := UiFleets.condition(state, f)
	line(UiKit.tr_fmt("FLEET_SUMMARY", {"ships": f.size(), "str": UiKit.units(UiFleets.strength(state, f) * 1000),
		"hull": UiNames.bar(c[0], c[1]), "ammo": UiNames.bar(c[2], c[3]) if c[3] > 0 else "—",
		"supply": TranslationServer.translate("FLEET_SUPPLIED" if UiFleets.supplied(state, f) else "FLEET_UNSUPPLIED")}), "Mono")
	line(UiFleets.status(state, f))
	# Doctrine (main spec 7.6)
	var d := row()
	_doctrine(d, f, "range", Fleet.RANGES, f.range_pref, "DOCTRINE_RANGE_%s")
	_doctrine(d, f, "target", Fleet.TARGETS, f.target_priority, "DOCTRINE_TARGET_%s")
	var retreats: Array = []
	for v in Fleet.RETREATS:
		retreats.append(str(v))
	_doctrine(d, f, "retreat", retreats, str(f.retreat_at), "DOCTRINE_RETREAT_%s")
	_doctrine(d, f, "stance", Fleet.STANCES, f.stance, "DOCTRINE_STANCE_%s")
	# Composition: one line per task force, with a split button.
	for i in f.task_forces.size():
		var tf_row := row()
		line(UiKit.tr_fmt("FLEET_TF", {"n": i + 1, "ships": UiFleets.composition(state, f.task_forces[i])}), "", tf_row)
		if f.task_forces.size() > 1:
			var ids: Array = []
			for sq: Array in f.task_forces[i]:
				ids.append_array(sq)
			button(TranslationServer.translate("FLEET_SPLIT_TF"), "Split_%d_%d" % [f.id, i], func() -> void:
				CommandQueue.submit_new(CmdSplitFleet.TYPE, {"fleet": f.id, "ships": ids}), tf_row)
	# Orders
	var o := row()
	var l := Fleets.lead(state, f)
	var nearby := _nearby_own(state, eid, l.system_id)
	if f.mission == "patrol":
		button(TranslationServer.translate("FLEET_END_PATROL"), "Patrol_%d" % f.id, func() -> void:
			CommandQueue.submit_new(CmdSetPatrol.TYPE, {"fleet": f.id, "systems": []}), o)
	elif not nearby.is_empty():
		button(TranslationServer.translate("FLEET_PATROL"), "Patrol_%d" % f.id, func() -> void:
			CommandQueue.submit_new(CmdSetPatrol.TYPE, {"fleet": f.id, "systems": nearby}), o)
	var hubs := [["FLEET_ESCORT_PICK", 0]]
	var selected := 0
	for h in AutoLogistics._own_holders(state, eid):
		if Shipyards.berths(state, h) > 0:
			if f.mission == "escort" and f.escort_hub == h:
				selected = hubs.size()
			hubs.append([UiKit.tr_fmt("FLEET_ESCORT_HUB", {"hub": UiNames.holder(state, h)}), h])
	if hubs.size() > 1:
		var esc := UiKit.options(hubs, selected)
		esc.name = "Escort_%d" % f.id
		esc.item_selected.connect(func(i: int) -> void:
			CommandQueue.submit_new(CmdSetEscort.TYPE, {"fleet": f.id, "hub": esc.get_item_metadata(i)}))
		o.add_child(esc)
	for fid: int in state.fleets.ordered():
		var other: Fleet = state.fleets.get_or(fid)
		var ol := Fleets.lead(state, other) if other.owner == eid and other.id != f.id else null
		if ol != null and ol.system_id == l.system_id and not ol.is_moving() and not l.is_moving():
			button(UiKit.tr_fmt("FLEET_MERGE", {"name": UiFleets.name_of(state, other)}), "Merge_%d_%d" % [f.id, other.id],
				func() -> void: CommandQueue.submit_new(CmdMergeFleets.TYPE, {"into": f.id, "from": other.id}), o)
	var name_edit := LineEdit.new()
	name_edit.name = "Name_%d" % f.id
	name_edit.placeholder_text = TranslationServer.translate("FLEET_RENAME_HINT")
	name_edit.custom_minimum_size.x = 160
	name_edit.text_submitted.connect(func(text: String) -> void:
		CommandQueue.submit_new(CmdRenameFleet.TYPE, {"fleet": f.id, "name": text}))
	o.add_child(name_edit)


func _doctrine(parent: Control, f: Fleet, field: String, values: Array, current: String, key_pattern: String) -> void:
	var items := []
	var selected := 0
	for v in values:
		if str(v) == current:
			selected = items.size()
		items.append([key_pattern % str(v).to_upper(), v])
	var opt := UiKit.options(items, selected)
	opt.name = "Doctrine_%s_%d" % [field, f.id]
	opt.item_selected.connect(func(i: int) -> void:
		var v: Variant = opt.get_item_metadata(i)
		CommandQueue.submit_new(CmdSetDoctrine.TYPE, {"fleet": f.id, field: int(v) if field == "retreat" else v}))
	parent.add_child(opt)


## Own systems within PATROL_LANES of a system, nearest first (at most CmdSetPatrol.MAX_SYSTEMS).
static func _nearby_own(state: MatchState, eid: int, system_id: int) -> Array:
	var dist := AutoLogistics.hops_within(state, system_id, PATROL_LANES, {})
	var ids: Array = []
	for sid: int in IdMap.sort_keys(dist.keys()):
		if state.galaxy.system(sid).owner == eid:
			ids.append(sid)
	ids.sort_custom(func(a: int, b: int) -> bool: return dist[a] < dist[b] or (dist[a] == dist[b] and a < b))
	return ids.slice(0, CmdSetPatrol.MAX_SYSTEMS)


## The M3 war toggle (owner decision 2026-10-02): unilateral war and peace with each other empire.
func _empires(state: MatchState, eid: int) -> void:
	heading("FLEETS_WAR_NOTE")
	var g := table(["FLEETS_COL_EMPIRE", "FLEETS_COL_RELATION", ""])
	for other: int in state.empires.ordered():
		if other == eid:
			continue
		var at_war := state.wars.has(Battles.war_key(eid, other))
		cell(g, UiNames.owner(state, other))
		cell(g, TranslationServer.translate("FLEETS_AT_WAR" if at_war else "FLEETS_AT_PEACE"))
		if at_war:
			button(TranslationServer.translate("FLEETS_MAKE_PEACE"), "Peace_%d" % other, func() -> void:
				CommandQueue.submit_new(CmdMakePeace.TYPE, {"empire": other}), g)
		else:
			button(TranslationServer.translate("FLEETS_DECLARE_WAR"), "War_%d" % other, func() -> void:
				CommandQueue.submit_new(CmdDeclareWar.TYPE, {"empire": other}), g)
