extends SceneTree
## Economy harness (M2 WP13, Sub-spec B20): all-AI matches for N years across seeds, reported against the B20
## targets. Usage: godot --headless -s tools/economy_harness.gd -- [seeds=5] [years=15] [size=small] [players=4] [first=1]
## [mode=neutral|species] (`first`: the first seed, to run a long check in chunks).
## neutral (owner decision 2026-10-02, M4 WP1): species traits are switched off in memory, so B20, calibrated
## without species, stays comparable across milestones; exit code 1 if fewer than 90% of empires meet it.
## species: traits on; reports B20 per species and exits 1 if any species meets it in fewer than half its
## empires (species economies may differ, none may collapse).

const SPECIES: Array[String] = ["human", "krothi", "vesskar", "thessari", "ohlan", "human", "krothi", "vesskar"]
const ALLOYS := "core:resource/alloys"
# B20 freighters (owner decision 2026-10-01): logistics health over the last year instead of a count.
const BUSY_AVG_MAX := 80  # average share of freighters busy, percent
const BUSY_HIGH := 95  # a month above this is a shortage month
const SHORT_MONTHS_MAX := 3


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 5
	var years := int(args[1]) if args.size() > 1 else 15
	var size := args[2] if args.size() > 2 else "small"
	var players := int(args[3]) if args.size() > 3 else 4
	var first := int(args[4]) if args.size() > 4 else 1
	var mode := args[5] if args.size() > 5 else "neutral"
	var loader := ContentLoader.new()
	loader.load_mods([])
	if mode == "neutral":
		for id: StringName in loader.db.ids("species"):
			(loader.db.get_def(id) as SpeciesDef).traits = [] as Array[StringName]
	print("mode: %s" % mode)
	var per_species := {}  # species -> [met, total]
	var met := 0
	var total := 0
	var worst_month_ms := 0.0
	for seed_value in seeds:
		var r := run(loader.db, seed_value + first, years, size, players)
		worst_month_ms = maxf(worst_month_ms, r["worst_month_ms"])
		print("seed %d (%s, %d years, %.1f s, month tick avg %.1f ms, worst %.1f ms):" % [seed_value + first, size, years, r["seconds"],
				r["avg_month_ms"], r["worst_month_ms"]])
		for e: Dictionary in r["empires"]:
			print("  %-10s first colony m%-3s colonies %2d shipyards %d freighters %2d (busy %3d%%, year avg %3d%%, %d short) alloys/mo %4d credits %6d lost %2d warships %2d  %s" % [
				e["species"], str(e["first_colony_month"]), e["colonies"], e["shipyards"], e["freighters"], e["busy_pct"],
				e["busy_avg"], e["short_months"], e["alloys_per_month"], e["credits"], e["lost"], e["warships"], "OK" if e["ok"] else "-"])
			total += 1
			if e["ok"]:
				met += 1
			var tally: Array = per_species.get(e["species"], [0, 0])
			per_species[e["species"]] = [tally[0] + (1 if e["ok"] else 0), tally[1] + 1]
	print("B20 targets met by %d of %d empires; worst month tick %.1f ms" % [met, total, worst_month_ms])
	var species_ok := true
	for sp: String in IdMap.sort_keys(per_species.keys()):
		var t: Array = per_species[sp]
		var ok: bool = t[0] * 2 >= t[1]
		species_ok = species_ok and ok
		print("species %-10s %d of %d %s" % [sp, t[0], t[1], "OK" if ok else ("MISS" if mode == "species" else "")])
	if mode == "species":
		quit(1 if years >= 15 and not species_ok else 0)
	else:
		quit(1 if years >= 15 and met * 10 < total * 9 else 0)


static func run(db: DefDatabase, seed_value: int, years: int, size: String, players: int) -> Dictionary:
	var settings := MatchSettings.new()
	settings.galaxy_size = "core:match_preset/size_" + size
	for i in players:
		settings.add_player(i, "core:species/" + SPECIES[i], "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, seed_value, db, errors)
	var none: Array[Command] = []
	var first_colony := {}
	var start_colonies := {}
	for eid: int in s.empires:
		start_colonies[eid] = _colonies(s, eid)
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var month_ms_total := 0.0
	var busy_hist := {}  # empire id -> busy percent per month, last 12 months
	for month in years * Calendar.MONTHS_PER_YEAR:
		for h in Calendar.HOURS_PER_MONTH - 1:
			Sim.step(s, none)
		var tm := Time.get_ticks_usec()
		Sim.step(s, none)  # the hour that runs the day and month ticks
		var ms := (Time.get_ticks_usec() - tm) / 1000.0
		worst = maxf(worst, ms)
		month_ms_total += ms
		for eid: int in s.empires:
			if not first_colony.has(eid) and _colonies(s, eid) > start_colonies[eid]:
				first_colony[eid] = month + 1
			var hist: Array = busy_hist.get(eid, [])
			hist.append(_freight(s, eid)[1])
			if hist.size() > Calendar.MONTHS_PER_YEAR:
				hist.pop_front()
			busy_hist[eid] = hist
	var out := []
	for eid: int in s.empires:
		var e: Empire = s.empires.get_or(eid)
		var alloys := 0
		for c: Colony in s.colonies.values():
			if c.owner == eid:
				alloys += int(c.last_produced.get(ALLOYS, 0)) - int(c.last_consumed.get(ALLOYS, 0))
		var fr := _freight(s, eid)
		var hist: Array = busy_hist.get(eid, [0])
		var sum := 0
		var short := 0
		for b: int in hist:
			sum += b
			if b > BUSY_HIGH:
				short += 1
		var shipyards := s.stations.values().filter(func(x: Station) -> bool:
			return x.owner == eid and x.operational and (db.get_def(StringName(x.def_id)) as StationDef).function == &"shipyard").size()
		var row := {
			"species": e.species.get_slice("/", 1), "first_colony_month": first_colony.get(eid, "-"),
			"colonies": _colonies(s, eid), "shipyards": shipyards, "freighters": fr[0], "busy_pct": fr[1],
			"busy_avg": FixedMath.floor_div(sum, maxi(1, hist.size())), "short_months": short,
			"alloys_per_month": FixedMath.floor_div(alloys, 1000),
			"credits": FixedMath.floor_div(int(e.treasury.get("core:resource/credits", 0)), 1000), "lost": e.losses.size(),
			"warships": s.units.values().filter(func(u: Unit) -> bool: return u.owner == eid and u.kind == "warship").size(),
		}
		# B20 (year 15): first colony by month 12; 6-10 colonies; 2-3 shipyards; 50-140 alloys/month (owner, 2026-10-01; was 60-120); freighters
		# not a bottleneck (last year: average use <= 80%, at most 3 months over 95%).
		row["ok"] = first_colony.get(eid, 999) <= 12 and row["colonies"] >= 6 and row["colonies"] <= 10 and shipyards >= 2 \
				and fr[0] > 0 and row["busy_avg"] <= BUSY_AVG_MAX and short <= SHORT_MONTHS_MAX \
				and row["alloys_per_month"] >= 50 and row["alloys_per_month"] <= 140
		out.append(row)
	return {"empires": out, "seconds": (Time.get_ticks_usec() - t0) / 1000000.0, "worst_month_ms": worst,
		"avg_month_ms": month_ms_total / maxi(1, years * Calendar.MONTHS_PER_YEAR)}


## [freighters, percent of them busy right now]
static func _freight(s: MatchState, eid: int) -> Array:
	var n := 0
	var busy := 0
	for u: Unit in s.units.values():
		if u.owner == eid and u.kind == "freighter":
			n += 1
			if not Freight.plan(s, u).is_empty():
				busy += 1
	return [n, FixedMath.floor_div(busy * 100, maxi(1, n))]


static func _colonies(s: MatchState, eid: int) -> int:
	return s.colonies.values().filter(func(c: Colony) -> bool: return c.owner == eid).size()
