extends Node
## Boot: shows the main menu (ui/ui_root.gd). Dev flags (after `--` on the command line):
##   --quickstart          start a debug match immediately (human + 3 AI) with a scout at the capital
##   --size=small|medium|large|huge   --seed=<text>
##   --view=galaxy|cluster|solar      initial instrument for the shots below
##   --screenshot=<path>   save a PNG after the camera settles, then quit
##   --perf=<seconds>      print average / worst FPS over that time, then quit
##   --ui=menu|setup       with --screenshot: capture that screen instead of a match
##   --load=<save>         open that save and unpause (with --speed=<1|2|4|8>, --perf=<seconds>)
##   --months=<n>          run the quickstart match n months before showing it
##   --screen=planet|sectors|logistics|stockpile|alerts|fleets|designer|battles|diplomacy|construction   (--tab=routes|demands|hubs|losses|empires) open that panel
##   --warships=<n>        quickstart: queue n standard destroyers at the human's first shipyard (Commands)
##   --meet                quickstart: send the scout to the nearest AI capital (first contact)

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
	elif _args.has("load"):
		_load_and_run()
	elif _args.has("quickstart") or _args.has("screenshot") or _args.has("perf"):
		_quickstart()


## --load=<save> [--speed=1|2|4|8] [--perf=<s>]: open a save, unpause at that speed, optionally measure FPS.
func _load_and_run() -> void:
	var errors := GameState.load_from(_args["load"])
	if not errors.is_empty():
		printerr("\n".join(errors))
		get_tree().quit(1)
		return
	($UI/UiRoot as UiRoot).show_hud()
	if _args.has("no-autosave"):
		GameState.autosave_enabled = false
	CommandQueue.submit_new(CmdSetSpeed.TYPE, {"speed": int(_args.get("speed", "1"))})
	CommandQueue.submit_new(CmdPause.TYPE, {"paused": 0})
	if _args.has("perf"):
		var start := GameState.state.tick
		await _measure(float(_args["perf"]))
		print("perf: %d sim hours in %s s" % [GameState.state.tick - start, _args["perf"]])
		get_tree().quit()


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
	_queue_warships(state, human.id, int(_args.get("warships", "0")))
	if _args.has("meet"):
		_scout_to_nearest_ai(state, human.id)
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


## --meet: the starting scout flies to the nearest AI capital (a normal move command), for first contact.
func _scout_to_nearest_ai(state: MatchState, eid: int) -> void:
	var scout: Unit = null
	for u: Unit in state.units.values():
		if u.owner == eid and u.kind == "scout":
			scout = u
	if scout == null:
		return
	var dist := AutoLogistics._hops_from(state, scout.system_id, {})
	var best := -1
	for e: Empire in state.empires.values():
		if e.id != eid:
			var sid := state.galaxy.planet(e.capital_planet).system_id
			if best < 0 or int(dist.get(sid, 9999)) < int(dist.get(best, 9999)):
				best = sid
	if best >= 0:
		Sim.execute(state, [CommandRegistry.create(CmdMoveUnit.TYPE, eid, {"unit": scout.id, "to": best})] as Array[Command])


func _queue_warships(state: MatchState, eid: int, n: int) -> void:
	var design := 0
	for did: int in state.designs.ordered():
		var d: ShipDesign = state.designs.get_or(did)
		if d.owner == eid and d.source.ends_with("destroyer_standard"):
			design = d.id
	for sid: int in state.stations.ordered():
		var y: Station = state.stations.get_or(sid)
		if y.owner == eid and design != 0 and Shipyards.check_design_ship(state, eid, y.id, design) == "":
			var cmds: Array[Command] = []
			for i in n:
				cmds.append(CommandRegistry.create(CmdQueueShip.TYPE, eid, {"station": y.id, "design": design}))
			Sim.execute(state, cmds)
			return


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
		"fleets":
			ui.fleets_screen._tab = _args.get("tab", "fleets")
			ui.toggle_screen(ui.fleets_screen)
		"designer":
			ui.toggle_screen(ui.designer_screen)
		"battles":
			ui.toggle_screen(ui.battles_screen)
		"diplomacy":
			ui.diplomacy_screen._tab = _args.get("tab", "empires")
			ui.toggle_screen(ui.diplomacy_screen)
		"construction":
			ui.open_construction(human.capital_planet)


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
