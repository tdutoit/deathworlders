extends SceneTree
## Galaxy generation stress run (M1 WP7): N seeds x 4 sizes, checking connectivity, system counts and
## capital spacing. Usage: godot --headless -s tools/galaxy_stress.gd -- [seeds=500]

const SIZES: Array[String] = ["small", "medium", "large", "huge"]
const PLAYERS: Array[String] = ["human", "vesskar", "krothi", "thessari"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 500
	var loader := ContentLoader.new()
	loader.load_mods([])
	var failures := 0
	var relaxed := 0
	for size in SIZES:
		var preset: MatchPresetDef = loader.db.get_def(StringName("core:match_preset/size_" + size))
		var settings := MatchSettings.new()
		settings.galaxy_size = String(preset.id)
		for i in PLAYERS.size():
			settings.add_player(i, "core:species/" + PLAYERS[i], "ai")
		var t0 := Time.get_ticks_msec()
		var slowest := 0
		for seed_value in seeds:
			var t1 := Time.get_ticks_msec()
			var errors: Array[String] = []
			var s := GalaxyGenerator.new_match(settings, seed_value, loader.db, errors)
			slowest = maxi(slowest, Time.get_ticks_msec() - t1)
			var problem := _check(s, preset)
			if problem == "spacing":
				relaxed += 1
			elif problem != "":
				failures += 1
				printerr("%s seed %d: %s" % [size, seed_value, problem])
		print("%-6s %d seeds in %d ms (slowest %d ms)" % [size, seeds, Time.get_ticks_msec() - t0, slowest])
	print("failures: %d, capital spacing relaxed: %d" % [failures, relaxed])
	quit(1 if failures > 0 else 0)


static func _check(s: MatchState, preset: MatchPresetDef) -> String:
	if s == null:
		return "no state"
	var g := s.galaxy
	if g.systems.size() != preset.target_systems:
		return "system count %d" % g.systems.size()
	var caps: Array[int] = []
	for eid: int in s.empires:
		caps.append(g.planet((s.empires.get_or(eid) as Empire).capital_planet).system_id)
	var first: int = g.systems.keys()[0]
	if _hops(g, first).size() != g.systems.size():
		return "not connected"
	for i in caps.size():
		var hops := _hops(g, caps[i])
		for j in range(i + 1, caps.size()):
			if hops[caps[j]] < preset.capital_min_jumps:
				return "spacing"
	return ""


static func _hops(g: Galaxy, start: int) -> Dictionary:
	var dist := {start: 0}
	var queue := [start]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for lid in g.system(at).lane_ids:
			var next := g.lane(lid).other_end(at)
			if not dist.has(next):
				dist[next] = dist[at] + 1
				queue.append(next)
	return dist
