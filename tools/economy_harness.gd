extends SceneTree
## Economy harness (M2 WP13, Sub-spec B20): all-AI matches for N years across seeds, reported against the B20
## targets. Usage: godot --headless -s tools/economy_harness.gd -- [seeds=5] [years=15] [size=small] [players=4]
## Exit code 1 if fewer than 90% of empires meet the year-15 targets (only checked when years >= 15).

const SPECIES: Array[String] = ["human", "krothi", "vesskar", "thessari", "ohlan", "human", "krothi", "vesskar"]
const ALLOYS := "core:resource/alloys"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 5
	var years := int(args[1]) if args.size() > 1 else 15
	var size := args[2] if args.size() > 2 else "small"
	var players := int(args[3]) if args.size() > 3 else 4
	var loader := ContentLoader.new()
	loader.load_mods([])
	var met := 0
	var total := 0
	var worst_month_ms := 0.0
	for seed_value in seeds:
		var r := run(loader.db, seed_value + 1, years, size, players)
		worst_month_ms = maxf(worst_month_ms, r["worst_month_ms"])
		print("seed %d (%s, %d years, %.1f s, month tick avg %.1f ms, worst %.1f ms):" % [seed_value + 1, size, years, r["seconds"],
				r["avg_month_ms"], r["worst_month_ms"]])
		for e: Dictionary in r["empires"]:
			print("  %-10s first colony m%-3s colonies %2d shipyards %d freighters %2d (busy %3d%%) alloys/mo %4d credits %6d lost %d  %s" % [
				e["species"], str(e["first_colony_month"]), e["colonies"], e["shipyards"], e["freighters"], e["busy_pct"],
				e["alloys_per_month"], e["credits"], e["lost"], "OK" if e["ok"] else "-"])
			total += 1
			if e["ok"]:
				met += 1
	print("B20 targets met by %d of %d empires; worst month tick %.1f ms" % [met, total, worst_month_ms])
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
	var out := []
	for eid: int in s.empires:
		var e: Empire = s.empires.get_or(eid)
		var alloys := 0
		for c: Colony in s.colonies.values():
			if c.owner == eid:
				alloys += int(c.last_produced.get(ALLOYS, 0)) - int(c.last_consumed.get(ALLOYS, 0))
		var freighters := 0
		var busy := 0
		for u: Unit in s.units.values():
			if u.owner == eid and u.kind == "freighter":
				freighters += 1
				if not Freight.plan(s, u).is_empty():
					busy += 1
		var shipyards := s.stations.values().filter(func(x: Station) -> bool:
			return x.owner == eid and x.operational and (db.get_def(StringName(x.def_id)) as StationDef).function == &"shipyard").size()
		var row := {
			"species": e.species.get_slice("/", 1), "first_colony_month": first_colony.get(eid, "-"),
			"colonies": _colonies(s, eid), "shipyards": shipyards, "freighters": freighters,
			"busy_pct": FixedMath.floor_div(busy * 100, maxi(1, freighters)), "alloys_per_month": FixedMath.floor_div(alloys, 1000),
			"credits": FixedMath.floor_div(int(e.treasury.get("core:resource/credits", 0)), 1000), "lost": e.losses.size(),
		}
		# B20 (year 15): first colony by month 12; 6-10 colonies; 2-3 shipyards; 20-40 freighters; 60-120 alloys/month.
		row["ok"] = first_colony.get(eid, 999) <= 12 and row["colonies"] >= 6 and row["colonies"] <= 10 and shipyards >= 2 \
				and freighters >= 20 and freighters <= 40 and row["alloys_per_month"] >= 60 and row["alloys_per_month"] <= 120
		out.append(row)
	return {"empires": out, "seconds": (Time.get_ticks_usec() - t0) / 1000000.0, "worst_month_ms": worst,
		"avg_month_ms": month_ms_total / maxi(1, years * Calendar.MONTHS_PER_YEAR)}


static func _colonies(s: MatchState, eid: int) -> int:
	return s.colonies.values().filter(func(c: Colony) -> bool: return c.owner == eid).size()
