extends SceneTree
## Determinism harness (M1 WP11, main spec 18.4). Exit code 1 on any mismatch.
## Usage: godot --headless -s tools/determinism_test.gd -- [seeds=20] [sizes=small,medium,large,huge] [months=60]
## Writes per-case monthly checksum files to user://determinism/ for cross-machine comparison
## (diff the folders from two machines).


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 20
	var sizes := (args[1] if args.size() > 1 else "small,medium,large,huge").split(",")
	var months := int(args[2]) if args.size() > 2 else 60
	var loader := ContentLoader.new()
	loader.load_mods([])
	if loader.report.has_errors():
		printerr(loader.report.format_text())
		quit(1)
		return
	var harness := DeterminismHarness.new(loader.db, loader.manifests)
	DirAccess.make_dir_recursive_absolute(harness.save_dir)
	var failures := 0
	var t0 := Time.get_ticks_msec()
	for size in sizes:
		for seed_value in seeds:
			var result := harness.run_case(size, 1000 + seed_value, months)
			print(("OK   " if result["ok"] else "FAIL ") + result["message"])
			if not result["ok"]:
				failures += 1
			var f := FileAccess.open(harness.save_dir.path_join("%s_%d.txt" % [size, 1000 + seed_value]), FileAccess.WRITE)
			f.store_string("\n".join(DeterminismHarness.checksum_lines(result["checksums"])) + "\n")
			f.close()
	print("%d case(s), %d failure(s), %d s; checksum files in %s" % [seeds * sizes.size(), failures,
			(Time.get_ticks_msec() - t0) / 1000, ProjectSettings.globalize_path(harness.save_dir)])
	quit(1 if failures > 0 else 0)
