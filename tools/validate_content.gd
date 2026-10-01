extends SceneTree
## Validates core plus mods headless (Sub-spec C14). Exit code 1 if there are errors.
## Usage: godot --headless -s tools/validate_content.gd [-- <mod_dir> ...]
## Without mod dirs it loads every mod in res://mods.


func _init() -> void:
	var dirs: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		dirs.append(arg)
	if dirs.is_empty():
		dirs = ContentLoader.discover("res://mods")
	var loader := ContentLoader.new()
	loader.load_mods(dirs)
	print(loader.report.format_text())
	var counts := PackedStringArray()
	for category: String in DefFactory.categories():
		counts.append("%s %d" % [category, loader.db.ids(category).size()])
	print("Defs: %s" % ", ".join(counts))
	print("content_hash: %08x" % loader.db.content_hash)
	quit(1 if loader.report.has_errors() else 0)
