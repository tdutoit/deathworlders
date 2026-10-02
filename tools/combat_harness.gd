extends SceneTree
## Combat harness (M3 WP6, Sub-spec A14/A26): seeded battles per matchup, reported against the A14 balance
## targets. Usage: godot --headless -s tools/combat_harness.gd -- [runs=200] [matchup filter substring]
## Prints one CSV row per matchup (name, runs, A win %, B win %, draws %, avg rounds, target, OK; the target is
## checked against A wins + half the draws) and exits
## 1 if any matchup misses its band. Then the species section (M4): standard cruisers per species pair at equal cost. Each battle is replayable from (match_seed, battle_id, rules hash).

const CRUISER := "core:hull/human_cruiser_mk1"  # slots: W_S, W_M, W_M, D_M, D_M, U_S, C_M
const AC := "core:component/autocannon_s"
const PL := "core:component/pulse_laser_s"
const RG := "core:component/railgun_m"
const HL := "core:component/heavy_laser_m"
const MP := "core:component/missile_pod_m"
const AP := "core:component/armor_plate"
const SG := "core:component/shield_gen"
const PD := "core:component/point_defence"

const DESIGNS := {
	"kinetic": [AC, RG, RG, AP, SG, "", ""],
	"kinetic_armour": [AC, RG, RG, AP, AP, "", ""],
	"kinetic_shield": [AC, RG, RG, SG, SG, "", ""],
	"energy": [PL, HL, HL, AP, SG, "", ""],
	"energy_shield": [PL, HL, HL, SG, SG, "", ""],
	"missile": [AC, MP, MP, AP, SG, "", ""],
	"missile_pd": [AC, MP, MP, AP, PD, "", ""],
	"kinetic_pd": [AC, RG, RG, AP, PD, "", ""],
}

## name, side A [design, count, range], side B [design, count, range], A win band [lo, hi] permille (or
## [-1, -1] to only report), optional starting range band (A14's "forced to close range": 2).
const MATCHUPS := [
	["mirror", ["kinetic", 6, "line"], ["kinetic", 6, "line"], [450, 550]],
	["armour_vs_kinetic", ["kinetic_armour", 6, "line"], ["kinetic_shield", 6, "line"], [700, 850]],
	["energy_vs_armour", ["energy", 6, "line"], ["kinetic_armour", 6, "line"], [700, 850]],
	["kinetic_vs_shield", ["kinetic", 6, "line"], ["energy_shield", 6, "line"], [700, 850]],
	# A14's "a hard counter holds to ~1.25x cost" conflicts with 70-85% at equal cost under A4-A10 (A14 known
	# issue 1); report-only until M4 (owner, 2026-10-01).
	["counter_holds_1.25x", ["energy", 4, "line"], ["kinetic_armour", 5, "line"], [-1, -1]],
	["missiles_standoff_no_pd", ["missile", 6, "standoff"], ["kinetic", 6, "line"], [600, 1000]],
	["missiles_standoff_vs_pd", ["missile", 6, "standoff"], ["kinetic_pd", 6, "line"], [500, 1000]],
	["missiles_forced_close", ["missile", 6, "close"], ["kinetic", 6, "close"], [0, 200], 2],
]
const ROUNDS_BAND := [8, 20]

var _db: DefDatabase
var _snapshot: Dictionary
var _a: int
var _b: int
var _arena: int


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 200
	var filter := args[1] if args.size() > 1 else ""
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "ai")
	settings.add_player(1, "core:species/human", "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 1, _db, errors)
	_a = s.empires.keys()[0]
	_b = s.empires.keys()[1]
	for sid: int in s.galaxy.systems.ordered():
		if s.galaxy.system(sid).owner == StateIO.NONE:
			_arena = sid
			break
	s.wars[Battles.war_key(_a, _b)] = true
	for eid: int in [_a, _b]:
		s.empire(eid).species = ""  # A14 is a species-neutral baseline: no trait modifiers (M4 WP1)
	_snapshot = s.to_dict()
	var params := [(_db.get_def(CombatRulesDef.ID) as Def).to_dict()]  # everything the battles read
	for cat in ["weapon_family", "component", "hull"]:
		for id: StringName in _db.ids(cat):
			params.append((_db.get_def(id) as Def).to_dict())
	var rules_hash := DetHash.hash_value(params)
	print("matchup,runs,a_win_pct,b_win_pct,draw_pct,avg_rounds,target,ok  (param_hash %08x)" % rules_hash)
	var failed := 0
	var all_rounds := 0
	var all_battles := 0
	for m: Array in MATCHUPS:
		if filter != "" and not String(m[0]).contains(filter):
			continue
		var wins := [0, 0, 0]
		var rounds := 0
		for run in runs:
			var res := _battle(m[1], m[2], 1000 + run, m[4] if m.size() > 4 else -1)
			wins[res[0]] += 1
			rounds += res[1]
		var a_win := FixedMath.floor_div(wins[0] * 1000 + wins[2] * 500, runs)  # a draw counts half
		var band: Array = m[3]
		var ok: bool = band[0] < 0 or (a_win >= band[0] and a_win <= band[1])
		if not ok:
			failed += 1
		all_rounds += rounds
		all_battles += runs
		print("%s,%d,%.1f,%.1f,%.1f,%.1f,%s,%s" % [m[0], runs, wins[0] * 100.0 / runs, wins[1] * 100.0 / runs,
			wins[2] * 100.0 / runs, rounds * 1.0 / runs, "-" if band[0] < 0 else "%d-%d%%" % [band[0] / 10, band[1] / 10],
			"OK" if ok else "MISS"])
	if filter == "" or filter == "species":
		failed += _species_report(maxi(10, runs / 5))  # 40 battles per side-B count at the default 200
	var avg := all_rounds * 1.0 / maxi(1, all_battles)
	var rounds_ok: bool = avg >= ROUNDS_BAND[0] and avg <= ROUNDS_BAND[1]
	print("average rounds %.1f (target %d-%d) %s" % [avg, ROUNDS_BAND[0], ROUNDS_BAND[1], "OK" if rounds_ok else "MISS"])
	quit(1 if failed > 0 or not rounds_ok else 0)


## One battle: [winner (0 A, 1 B, 2 draw), rounds].
func _battle(side_a: Array, side_b: Array, seed_value: int, start_band := -1) -> Array:
	var s := MatchState.from_dict(_snapshot)
	s.defs = _db
	s.match_seed = seed_value
	_fleet(s, _a, side_a)
	_fleet(s, _b, side_b)
	if start_band >= 0:
		Battles._start_battles(s)
		for b: Battle in s.battles.values():
			b.band = start_band
	for h in 200:
		s.clear_scratch()
		Battles.tick(s)
		if s.battles.is_empty() and not s.reports.is_empty():
			break
	if s.reports.is_empty():
		return [2, 0]
	var rep: Dictionary = (s.reports.values()[0] as BattleReport).data
	var ra := String(rep["results"][0])
	var rb := String(rep["results"][1])
	var winner: int = 0 if ra.ends_with("victory") and not rb.ends_with("victory") else (1 if rb.ends_with("victory") and not ra.ends_with("victory") else 2)
	return [winner, int(rep["rounds"])]


func _fleet(s: MatchState, owner: int, spec: Array) -> void:
	var ids: Array[int] = []
	for i in int(spec[1]):
		var u := Shipyards.spawn(s, owner, CRUISER, _arena)
		u.components.assign(DESIGNS[spec[0]])
		Fleets.arm(s, u)
		ids.append(u.id)
	var f := Fleets.create(s, owner, ids)
	f.range_pref = spec[2]
	f.retreat_at = 0  # A14 prototype runs to the end; morale-driven retreat still applies


## M4 WP1 (owner target 2026-10-02): each species' standard cruiser against every other's at exactly equal battle
## value (8 ships against the cost-equal count, interpolated between the two neighbouring counts), each side
## with its own species traits. Target: every species averages 40-60%, no pairing worse than 25/75 (A wins +
## half the draws). Returns the number of misses.
const SPECIES := ["human", "vesskar", "krothi", "ohlan", "thessari"]
const SPECIES_SHIPS := 8
const SPECIES_AVG := [400, 600]
const SPECIES_PAIR_MIN := 250


func _species_report(runs: int) -> int:
	var totals := {}
	var misses := 0
	print("species_cruisers,a,b,a_win_pct  (equal cost, interpolated; target avg 40-60%, pairs 25-75%)")
	for i in SPECIES.size():
		for j in range(i + 1, SPECIES.size()):
			var da: DesignDef = _db.get_def(StringName("core:design/%s_cruiser_standard" % SPECIES[i]))
			var db: DesignDef = _db.get_def(StringName("core:design/%s_cruiser_standard" % SPECIES[j]))
			var ha := String(da.hull)
			var hb := String(db.hull)
			var ca := Array(da.components).map(func(c: StringName) -> String: return String(c))
			var cb := Array(db.components).map(func(c: StringName) -> String: return String(c))
			var arena := MatchupPredictor._prepare(_db, "core:species/" + SPECIES[i], "core:species/" + SPECIES[j])
			var x1000 := FixedMath.floor_div(SPECIES_SHIPS * MatchupPredictor._value(_db, ha, ca) * 1000, MatchupPredictor._value(_db, hb, cb))
			var lo := maxi(1, x1000 / 1000)
			var frac := x1000 - lo * 1000
			var w := FixedMath.floor_div(_rate(arena, ha, ca, hb, cb, lo, runs) * (1000 - frac) + _rate(arena, ha, ca, hb, cb, lo + 1, runs) * frac, 1000)
			var ok := mini(w, 1000 - w) >= SPECIES_PAIR_MIN
			misses += 0 if ok else 1
			print("species,%s,%s,%.1f,%s" % [SPECIES[i], SPECIES[j], w / 10.0, "OK" if ok else "MISS"])
			totals[SPECIES[i]] = int(totals.get(SPECIES[i], 0)) + w
			totals[SPECIES[j]] = int(totals.get(SPECIES[j], 0)) + 1000 - w
	for sp: String in SPECIES:
		var avg := FixedMath.floor_div(int(totals[sp]), SPECIES.size() - 1)
		var ok: bool = avg >= SPECIES_AVG[0] and avg <= SPECIES_AVG[1]
		misses += 0 if ok else 1
		print("species_avg,%s,%.1f,%s" % [sp, avg / 10.0, "OK" if ok else "MISS"])
	return misses


## A win permille (draws half) over `runs` seeded battles: SPECIES_SHIPS of A against nb of B.
func _rate(arena: Array, ha: String, ca: Array, hb: String, cb: Array, nb: int, runs: int) -> int:
	var t := [0, 0, 0]
	for run in runs:
		t[MatchupPredictor._battle(_db, arena, run + 1, [ha, ca, SPECIES_SHIPS], [hb, cb, nb])] += 1
	return FixedMath.floor_div(t[0] * 1000 + t[2] * 500, runs)
