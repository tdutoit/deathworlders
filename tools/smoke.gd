extends SceneTree
## Quick smoke check for feature WPs (M5 workflow): loads content, runs a small all-AI match for N months
## and prints each empire's research. Fails on content errors or a script error (Godot exits non-zero
## when a script fails to compile). Usage: godot --headless -s tools/smoke.gd -- [months=24] [seed=1001]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 24
	var seed_value := int(args[1]) if args.size() > 1 else 1001
	var loader := ContentLoader.new()
	loader.load_mods([])
	if loader.report.has_errors():
		printerr(loader.report.format_text())
		quit(1)
		return
	var settings := MatchSettings.new()
	settings.galaxy_size = "core:match_preset/size_small"
	var species := ["human", "vesskar", "krothi", "thessari"]
	for i in species.size():
		settings.add_player(i, "core:species/" + species[i], "ai")
	var errors: Array[String] = []
	var state := GalaxyGenerator.new_match(settings, seed_value, loader.db, errors)
	if state == null:
		printerr(", ".join(errors))
		quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while state.tick < months * Calendar.HOURS_PER_MONTH:
		Sim.step(state, [])
	for eid: int in state.empires.ordered():
		var e := state.empire(eid)
		print("empire %d %s: %d techs %s, queue %s, RP banked %d" % [eid, e.species, e.techs.size(),
			IdMap.sort_keys(e.techs.keys()), e.research_queue, int(e.treasury.get(Research.RES, 0)) / 1000])
		var funcs := {}
		for sid: int in state.stations.ordered():
			var s: Station = state.stations.get_or(sid)
			if s.owner == eid:
				var f := String((loader.db.get_def(StringName(s.def_id)) as StationDef).function) + ("" if s.operational else "(building)")
				funcs[f] = int(funcs.get(f, 0)) + 1
		print("  stations ", funcs)
		var k: Knowledge = state.knowledge.get_or(eid)
		if k != null:
			print("  fog: %d explored, %d covered of %d systems, %d foreign units seen, %d ghosts" % [k.explored.size(),
				k.covered.size(), state.galaxy.systems.size(), k.visible.size(), k.ghosts.size()])
	print("smoke OK: %d months in %d ms, checksum %d" % [months, Time.get_ticks_msec() - t0, state.checksum()["total"]])
	quit(0)
