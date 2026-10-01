extends Node
## Loads content Defs from core and mods into the layered Def database (Sub-spec C).
## The Defs themselves live in a frozen DefDatabase (sim/defs); this node only owns it.

const MODS_DIR := "res://mods"

var defs: DefDatabase
var report: ContentReport


func _ready() -> void:
	load_translations()
	load_content()


## Registers the imported core translations (loc/*.translation, Sub-spec C13). Mod loc comes later.
func load_translations() -> void:
	var dir := DirAccess.open("res://loc")
	if dir == null:
		return
	for f in dir.get_files():
		var path := "res://loc/" + f.trim_suffix(".remap")
		if path.ends_with(".translation"):
			TranslationServer.add_translation(load(path))


## (Re)loads core plus every mod in MODS_DIR. Prints the report if anything went wrong.
func load_content() -> ContentReport:
	var loader := ContentLoader.new()
	loader.load_mods(ContentLoader.discover(MODS_DIR))
	defs = loader.db
	report = loader.report
	if not report.entries.is_empty():
		printerr(report.format_text())
	return report
