class_name MatchupPredictor
extends RefCounted
## The Ship Designer's "vs enemy design" prediction (F10; owner decision 2026-10-02: on click, 20 battles).
## Runs quick headless battles in a throwaway arena match (never the live game state): side A flies the
## design being edited, side B the enemy design, at roughly equal battle value (A1 cost). Full visibility
## in M3, so the enemy design is used as built.

const RUNS := 20
const SHIPS_A := 4
const MAX_SHIPS := 12
const ROUND_HOURS := 200  # battles end well before this (A4 round cap)

static var _snapshot := {}
static var _owners: Array[int] = []
static var _arena := 0


## {win, loss, draw (percent), ships_a, ships_b} or {"error": text}.
static func predict(db: DefDatabase, hull_a: String, comps_a: Array, hull_b: String, comps_b: Array) -> Dictionary:
	var cost_a := _value(db, hull_a, comps_a)
	var cost_b := _value(db, hull_b, comps_b)
	if cost_a <= 0 or cost_b <= 0 or ShipStats.of(db, hull_a, comps_a).weapons.is_empty():
		return {"error": "DESIGNER_PREDICT_UNARMED"}
	_prepare(db)
	var ships_b := clampi(roundi(SHIPS_A * cost_a / float(cost_b)), 1, MAX_SHIPS)
	var tally := [0, 0, 0]
	for run in RUNS:
		tally[_battle(db, run + 1, [hull_a, comps_a, SHIPS_A], [hull_b, comps_b, ships_b])] += 1
	return {"win": tally[0] * 100 / RUNS, "loss": tally[1] * 100 / RUNS, "draw": tally[2] * 100 / RUNS,
		"ships_a": SHIPS_A, "ships_b": ships_b}


static func _value(db: DefDatabase, hull: String, comps: Array) -> int:
	var total := 0
	var c := ShipStats.cost(db, hull, comps)
	for res: String in c:
		var rd := db.get_def(StringName(res)) as ResourceDef
		total += int(c[res]) * (rd.base_value if rd else 1000)
	return total


static func _prepare(db: DefDatabase) -> void:
	if not _snapshot.is_empty():
		return
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "ai")
	settings.add_player(1, "core:species/human", "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 1, db, errors)
	_owners.assign(s.empires.keys())
	for sid: int in s.galaxy.systems.ordered():
		if s.galaxy.system(sid).owner == StateIO.NONE:
			_arena = sid
			break
	s.wars[Battles.war_key(_owners[0], _owners[1])] = true
	_snapshot = s.to_dict()


## 0 = A won, 1 = B won, 2 = draw.
static func _battle(db: DefDatabase, seed_value: int, a: Array, b: Array) -> int:
	var s := MatchState.from_dict(_snapshot)
	s.defs = db
	s.match_seed = seed_value
	for side in 2:
		var spec: Array = [a, b][side]
		var ids: Array[int] = []
		for i in int(spec[2]):
			var u := Shipyards.spawn(s, _owners[side], spec[0], _arena)
			u.components.assign(spec[1])
			Fleets.arm(s, u)
			ids.append(u.id)
		Fleets.create(s, _owners[side], ids)
	for h in ROUND_HOURS:
		s.clear_scratch()
		Battles.tick(s)
		if s.battles.is_empty() and not s.reports.is_empty():
			break
	if s.reports.is_empty():
		return 2
	var rep: Dictionary = (s.reports.values()[0] as BattleReport).data
	var ra := String(rep["results"][0])
	var rb := String(rep["results"][1])
	if ra.ends_with("victory") and not rb.ends_with("victory"):
		return 0
	if rb.ends_with("victory") and not ra.ends_with("victory"):
		return 1
	return 2
