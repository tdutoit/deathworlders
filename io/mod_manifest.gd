class_name ModManifest
extends RefCounted
## A mod's mod.json (Sub-spec C10).

var dir: String
var id: String
var name: String
var version: String
var game_version: String
var dependencies: Array[Dictionary] = []  # {id, version}
var load_after: Array[String] = []
var load_before: Array[String] = []
var affects_sim := true
var has_scripts := false


## Reads dir/mod.json; returns null and reports errors if it is missing or malformed.
static func read(mod_dir: String, report: ContentReport) -> ModManifest:
	var path := mod_dir.path_join("mod.json")
	var label := mod_dir.get_file()
	if not FileAccess.file_exists(path):
		report.error(label, "mod.json", "missing mod.json")
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		report.error(label, "mod.json", "JSON error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null
	if not json.data is Dictionary:
		report.error(label, "mod.json", "must be a JSON object")
		return null
	var d: Dictionary = json.data
	var m := ModManifest.new()
	m.dir = mod_dir
	m.id = str(d.get("id", ""))
	if not DefIds.is_valid_mod_id(m.id):
		report.error(label, "mod.json", "id must be lowercase [a-z0-9_], got '%s'" % m.id)
		return null
	label = m.id
	m.name = str(d.get("name", m.id))
	m.version = str(d.get("version", ""))
	m.game_version = str(d.get("game_version", ""))
	m.affects_sim = d.get("affects_sim", true) == true
	m.has_scripts = d.get("has_scripts", false) == true
	var ok := true
	if Semver.parse(m.version).is_empty():
		report.error(label, "mod.json", "version must be major.minor.patch, got '%s'" % m.version)
		ok = false
	if not Semver.is_valid_constraint(m.game_version):
		report.error(label, "mod.json", "malformed game_version constraint '%s'" % m.game_version)
		ok = false
	for dep: Variant in d.get("dependencies", []):
		if not dep is Dictionary or not DefIds.is_valid_mod_id(str(dep.get("id", ""))) \
				or not Semver.is_valid_constraint(str(dep.get("version", ""))):
			report.error(label, "mod.json", "malformed dependency %s" % JSON.stringify(dep))
			ok = false
			continue
		m.dependencies.append({"id": str(dep["id"]), "version": str(dep.get("version", ""))})
	for hint: Variant in d.get("load_after", []):
		m.load_after.append(str(hint))
	for hint: Variant in d.get("load_before", []):
		m.load_before.append(str(hint))
	return m if ok else null
