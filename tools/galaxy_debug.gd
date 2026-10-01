extends SceneTree
## Prints a generated galaxy for eyeballing (M1 WP7).
## Usage: godot --headless -s tools/galaxy_debug.gd -- [size] [seed text] [players]
##   size: small | medium | large | huge (default small); players: species names, e.g. human,krothi


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var size := args[0] if args.size() > 0 else "small"
	var seed_text := args[1] if args.size() > 1 else "debug"
	var species := (args[2] if args.size() > 2 else "human,vesskar,krothi").split(",")
	var loader := ContentLoader.new()
	loader.load_mods([])
	var settings := MatchSettings.new()
	settings.galaxy_size = "core:match_preset/size_" + size
	settings.seed_text = seed_text
	for i in species.size():
		settings.add_player(i, "core:species/" + species[i], "human" if i == 0 else "ai")
	var errors: Array[String] = []
	var t0 := Time.get_ticks_msec()
	var state := GalaxyGenerator.new_match(settings, DetRng.match_seed_from_text(seed_text), loader.db, errors)
	var ms := Time.get_ticks_msec() - t0
	if state == null:
		printerr("\n".join(errors))
		quit(1)
		return
	print_galaxy(state)
	print("generated in %d ms; checksum %08x" % [ms, state.checksum()["total"]])
	quit(0)


static func print_galaxy(state: MatchState) -> void:
	var g := state.galaxy
	for cid: int in g.clusters:
		var c := g.cluster(cid)
		print("Cluster %d %s at (%d, %d), %d systems" % [c.id, c.name, c.x, c.y, c.system_ids.size()])
		for sid in c.system_ids:
			var s := g.system(sid)
			var links := PackedStringArray()
			for lid in s.lane_ids:
				var l := g.lane(lid)
				links.append("%s%d(%d)" % ["*" if lid in g.corridors else "", l.other_end(sid), l.length])
			var owner := " OWNER %d" % s.owner if s.owner != 0 else ""
			print("  %3d %-14s %-22s %d planets  lanes %s%s" % [s.id, s.name, s.star_type.get_slice("/", 1),
					s.planet_ids.size(), " ".join(links), owner])
	var lengths: Array[int] = []
	var corridor_lengths: Array[int] = []
	for lid: int in g.lanes:
		(corridor_lengths if lid in g.corridors else lengths).append(g.lane(lid).length)
	lengths.sort()
	corridor_lengths.sort()
	print("systems %d, planets %d, lanes %d (lengths %d-%d, median %d), corridors %d (lengths %d-%d)" % [
		g.systems.size(), g.planets.size(), lengths.size(), lengths.front(), lengths.back(),
		lengths[lengths.size() / 2], corridor_lengths.size(), corridor_lengths.front(), corridor_lengths.back()])
	for eid: int in state.empires:
		var e: Empire = state.empires.get_or(eid)
		var cap := g.planet(e.capital_planet)
		print("empire %d %s slot %d: capital %s (%s, %s) in %s" % [e.id, e.species, e.player_slot, cap.name,
				cap.planet_type.get_slice("/", 1), cap.size, g.system(cap.system_id).name])
