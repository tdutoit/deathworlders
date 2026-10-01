extends Node
## Boot: shows the main menu (ui/ui_root.gd). Dev flags (after `--` on the command line):
##   --quickstart          start a debug match immediately (human + 3 AI) with a scout at the capital
##   --size=small|medium|large|huge   --seed=<text>
##   --view=galaxy|cluster|solar      initial instrument for the shots below
##   --screenshot=<path>   save a PNG after the camera settles, then quit
##   --perf=<seconds>      print average / worst FPS over that time, then quit
##   --ui=menu|setup       with --screenshot: capture that screen instead of a match
##   --months=<n>          run the quickstart match n months before showing it
##   --screen=planet|sectors|logistics|stockpile|alerts   (--tab=routes|demands|hubs|losses) open that panel

var _args := {}


func _ready() -> void:
	($UI/UiRoot as UiRoot).view_manager = $ViewContainer
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if _args.has("ui") and _args.has("screenshot"):
		if _args["ui"] == "setup":
			($UI/UiRoot as UiRoot).show_setup()
		await _wait(0.6)
		_save_screenshot()
	elif _args.has("quickstart") or _args.has("screenshot") or _args.has("perf"):
		_quickstart()


func _quickstart() -> void:
	var settings := MatchSettings.new()
	settings.galaxy_size = "core:match_preset/size_" + _args.get("size", "small")
	settings.seed_text = _args.get("seed", "Sol forever")
	var species := ["human", "vesskar", "krothi", "thessari"]
	for i in species.size():
		settings.add_player(i, "core:species/" + species[i], "human" if i == 0 else "ai")
	var errors := GameState.start_new_match(settings, DetRng.match_seed_from_text(settings.seed_text))
	if not errors.is_empty():
		printerr("\n".join(errors))
		return
	var state := GameState.state
	var human: Empire = state.empires.get_or(GameState.first_human_empire())
	var home := state.galaxy.planet(human.capital_planet).system_id
	var spawn := CommandRegistry.create(CmdDebugSpawnScout.TYPE, human.id, {"system": home})
	Sim.execute(state, [spawn] as Array[Command])
	var none: Array[Command] = []
	for h in int(_args.get("months", "0")) * Calendar.HOURS_PER_MONTH:
		Sim.step(state, none)
	await _show_view(home)
	_open_screen(human)
	if _args.has("screenshot"):
		await _wait(1.2)
		_save_screenshot()
	elif _args.has("perf"):
		await _measure(float(_args["perf"]))
		get_tree().quit()


func _show_view(home: int) -> void:
	var vm: ViewManager = $ViewContainer
	match _args.get("view", "galaxy"):
		"cluster":
			var s := GameState.state.galaxy.system(home)
			vm.rig.map_to(Vector2(s.x, s.y), ViewManager.CLUSTER_VIEW_SIZE, true)
		"solar":
			await vm.dive_system(home)


func _open_screen(human: Empire) -> void:
	var ui := $UI/UiRoot as UiRoot
	match _args.get("screen", ""):
		"planet":
			EventBus.selection_changed.emit("planet", human.capital_planet)
		"sectors":
			ui.toggle_screen(ui.sector_screen)
		"logistics":
			ui.logistics_screen._tab = _args.get("tab", "routes")
			ui.toggle_screen(ui.logistics_screen)
		"stockpile":
			ui.toggle_screen(ui.stockpile_screen)
		"alerts":
			ui.toggle_screen(ui.alerts_screen)


func _save_screenshot() -> void:
	get_viewport().get_texture().get_image().save_png(_args["screenshot"])
	print("screenshot saved: ", _args["screenshot"])
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _measure(seconds: float) -> void:
	await _wait(0.5)
	var frames := 0
	var worst := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < seconds * 1000000.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	var avg := frames / ((Time.get_ticks_usec() - start) / 1000000.0)
	print("perf: %.1f fps average, worst frame %.1f ms (%d frames)" % [avg, worst, frames])
