extends SceneTree
## Performance check (M2-M4 DoD): a huge galaxy with 8 AI empires runs to year `years`; from year `war_year`
## pairs of empires in contact are put at war (if their own AIs haven't started one), so the measured year
## has wars under way. Reports the worst and average sim hour over the last year and saves the match for the
## frame-rate check: godot --path . -- --load=<save> --speed=8 --perf=20 --no-autosave
## Usage: godot --headless -s tools/perf_huge.gd -- [seed=1] [years=15] [war_year=12] [save=user://perf_huge.sav]

const SPECIES: Array[String] = ["human", "krothi", "vesskar", "thessari", "ohlan", "human", "krothi", "vesskar"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var years := int(args[1]) if args.size() > 1 else 15
	var war_year := int(args[2]) if args.size() > 2 else 12
	var path := args[3] if args.size() > 3 else "user://perf_huge.sav"
	var loader := ContentLoader.new()
	loader.load_mods([])
	var settings := MatchSettings.new()
	settings.galaxy_size = "core:match_preset/size_huge"
	for i in SPECIES.size():
		settings.add_player(i, "core:species/" + SPECIES[i], "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, seed_value, loader.db, errors)
	var none: Array[Command] = []
	var worst := 0
	var total := 0
	var hours := 0
	var t0 := Time.get_ticks_msec()
	for m in years * Calendar.MONTHS_PER_YEAR:
		if m == (war_year - 1) * Calendar.MONTHS_PER_YEAR:
			_start_wars(s)
		var measure := m >= (years - 1) * Calendar.MONTHS_PER_YEAR
		for h in Calendar.HOURS_PER_MONTH:
			var t := Time.get_ticks_usec()
			Sim.step(s, none)
			if measure:
				var us := Time.get_ticks_usec() - t
				worst = maxi(worst, us)
				total += us
				hours += 1
		if m % Calendar.MONTHS_PER_YEAR == Calendar.MONTHS_PER_YEAR - 1:
			print("year %d: %d wars, %d warships, %d battles fought, %.0f s" % [m / 12 + 1, s.wars.size(),
				s.units.values().filter(func(u: Unit) -> bool: return u.kind == "warship").size(), s.reports.size(),
				(Time.get_ticks_msec() - t0) / 1000.0])
	print("last year: worst hour %.1f ms, average hour %.2f ms (DoD: worst under 50 ms)" % [worst / 1000.0, total / 1000.0 / maxi(1, hours)])
	var err := SaveGame.write(path, s, CommandSchedule.new(), loader.db, loader.manifests)
	print("saved %s %s" % [ProjectSettings.globalize_path(path), err])
	quit()


## Neighbouring pairs in contact without a war go to war (breaking a non-aggression pact if they have one).
func _start_wars(s: MatchState) -> void:
	var ids: Array = s.empires.ordered()
	for i in range(0, ids.size() - 1, 2):
		var a: int = ids[i]
		var b: int = ids[i + 1]
		if s.wars.has(Battles.war_key(a, b)):
			continue
		if not Relations.has_contact(s, a, b):
			Relations._meet(s, a, b)
			Relations._meet(s, b, a)
		for t: Treaty in Treaties.between(s, a, b):
			Treaties.cancel(s, t, a)
		Sim.execute(s, [CommandRegistry.create(CmdDeclareWar.TYPE, a, {"empire": b})] as Array[Command])
	print("wars started: %d" % s.wars.size())
