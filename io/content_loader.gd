class_name ContentLoader
extends RefCounted
## Loads core plus mods into a frozen DefDatabase (Sub-spec C6, C10).
##
## Steps: read manifests -> check versions and dependencies -> load order -> apply every Def file
## in each mod (sorted by path) -> validate the merged result -> freeze.
## Usage: var loader := ContentLoader.new(); loader.load_mods(dirs); loader.db, loader.report.

const CORE_DIR := "res://data/core"
const CORE_ID := "core"
const OPS: Array[String] = ["add", "override", "patch", "remove"]
const MAX_SAFE_INT := 9007199254740992  # 2^53: larger JSON numbers lost precision while parsing

var db := DefDatabase.new()
var report := ContentReport.new()
var manifests := {}  # mod id -> ModManifest, for every mod that loaded

var _set_by := {}  # "id.field" -> mod_id of the last patch "set", for conflict warnings


## Mod folders (containing mod.json) directly under root, sorted by name.
static func discover(root: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(root)
	if d == null:
		return out
	var names := d.get_directories()
	names.sort()
	for n in names:
		if FileAccess.file_exists(root.path_join(n).path_join("mod.json")):
			out.append(root.path_join(n))
	return out


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## Loads core plus the given mod folders. Always freezes db; check report.has_errors().
func load_mods(mod_dirs: Array[String]) -> void:
	var found := _read_manifests(mod_dirs)
	var order := _load_order(found)
	report.load_order = order
	for mod_id in order:
		manifests[mod_id] = found[mod_id]
		_load_mod(found[mod_id])
	_validate()
	db.freeze()


func _read_manifests(mod_dirs: Array[String]) -> Dictionary:
	var dirs: Array[String] = [CORE_DIR]
	dirs.append_array(mod_dirs)
	var manifests := {}
	for dir in dirs:
		var m := ModManifest.read(dir, report)
		if m == null:
			continue
		if manifests.has(m.id):
			report.error(m.id, "mod.json", "duplicate mod id (also in %s)" % manifests[m.id].dir)
			continue
		if m.id != CORE_ID and dir == CORE_DIR or m.id == CORE_ID and dir != CORE_DIR:
			report.error(m.id, "mod.json", "the id 'core' is reserved for %s" % CORE_DIR)
			continue
		if not Semver.satisfies(game_version(), m.game_version):
			report.error(m.id, "mod.json", "needs game version %s, this is %s" % [m.game_version, game_version()])
			continue
		manifests[m.id] = m
	# Drop mods whose dependencies are missing or the wrong version, until nothing changes.
	var changed := true
	while changed:
		changed = false
		for id: String in IdMap.sort_keys(manifests.keys()):
			var m: ModManifest = manifests[id]
			for dep in m.dependencies:
				var target: ModManifest = manifests.get(dep["id"])
				var problem := ""
				if target == null:
					problem = "missing dependency '%s'" % dep["id"]
				elif not Semver.satisfies(target.version, dep["version"]):
					problem = "needs %s %s, found %s" % [dep["id"], dep["version"], target.version]
				if problem != "":
					report.error(id, "mod.json", problem + "; mod not loaded")
					manifests.erase(id)
					changed = true
					break
	return manifests


## Topological order: dependencies and load_after/load_before hints are edges; among mods that are
## ready, core goes first, then alphabetical. Mods in a cycle are reported and skipped.
func _load_order(manifests: Dictionary) -> Array[String]:
	var after := {}  # mod -> mods that must load before it
	for id: String in manifests:
		after[id] = {}
	for id: String in manifests:
		var m: ModManifest = manifests[id]
		for dep in m.dependencies:
			after[id][dep["id"]] = true
		for other in m.load_after:
			if manifests.has(other):
				after[id][other] = true
		for other in m.load_before:
			if manifests.has(other):
				after[other][id] = true
		if id != CORE_ID and manifests.has(CORE_ID):
			after[id][CORE_ID] = true
	var order: Array[String] = []
	var done := {}
	while order.size() < manifests.size():
		var ready: Array[String] = []
		for id: String in IdMap.sort_keys(manifests.keys()):
			if not done.has(id) and (after[id] as Dictionary).keys().all(func(x: String) -> bool: return done.has(x)):
				ready.append(id)
		if ready.is_empty():
			var stuck := []
			for id: String in IdMap.sort_keys(manifests.keys()):
				if not done.has(id):
					stuck.append(id)
			for id: String in stuck:
				report.error(id, "mod.json", "load order cycle between %s; mod not loaded" % ", ".join(stuck))
			break
		var next := ready[0]
		order.append(next)
		done[next] = true
	return order


func _load_mod(m: ModManifest) -> void:
	for path in _def_files(m.dir.path_join("defs")):
		var rel := path.trim_prefix(m.dir + "/")
		if path.ends_with(".json"):
			for entry in _read_json_entries(m, path, rel):
				_apply_entry(m, rel, entry)
		elif path.ends_with(".tres"):
			_load_tres(m, path, rel)


func _read_json_entries(m: ModManifest, path: String, rel: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		report.error(m.id, rel, "JSON error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return out
	var errors: Array[String] = []
	var data: Variant = _ints_only(json.data, "", errors)
	if not errors.is_empty():
		for e in errors:
			report.error(m.id, rel, e)
		return out
	var items: Array = data if data is Array else [data]
	for item: Variant in items:
		if item is Dictionary:
			out.append(item)
		else:
			report.error(m.id, rel, "each Def must be a JSON object")
	return out


## JSON numbers arrive as floats; whole numbers become ints, anything else is an error.
func _ints_only(v: Variant, where: String, errors: Array[String]) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			if v != floorf(v) or absf(v) > MAX_SAFE_INT:
				errors.append("%s: %s is not a whole number (the sim uses ints only)" % [where, v])
				return 0
			return int(v)
		TYPE_ARRAY:
			var out := []
			for i in v.size():
				out.append(_ints_only(v[i], "%s[%d]" % [where, i], errors))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in v:
				out[k] = _ints_only(v[k], "%s.%s" % [where, k] if where != "" else str(k), errors)
			return out
	return v


func _apply_entry(m: ModManifest, rel: String, entry: Dictionary) -> void:
	var op := str(entry.get("op", "add"))
	var category := str(entry.get("category", ""))
	if not op in OPS:
		report.error(m.id, rel, "unknown op '%s' (use %s)" % [op, ", ".join(OPS)])
		return
	if DefFactory.create(category) == null:
		report.error(m.id, rel, "unknown category '%s' (known: %s)" % [category, ", ".join(DefFactory.categories())])
		return
	var id := DefIds.resolve_own(str(entry.get("id", "")), m.id, category)
	if id == "" or DefIds.category_of(id) != category:
		report.error(m.id, rel, "invalid id '%s' for category '%s'" % [entry.get("id", ""), category])
		return
	var errors: Array[String] = []
	match op:
		"add", "override":
			var def := DefFactory.from_dict(entry, m.id, errors)
			if def != null:
				_put(m, rel, op, def)
		"patch":
			var def := db.get_def(StringName(id))
			if def == null:
				report.error(m.id, rel, "patch target '%s' does not exist" % id)
				return
			for field in DefFactory.apply_patch(def, entry, m.id, errors):
				var key := id + "." + field
				if _set_by.has(key) and _set_by[key] != m.id:
					report.warning(m.id, rel, "%s: '%s' was set by %s; %s wins (loads later)" % [id, field, _set_by[key], m.id])
				_set_by[key] = m.id
			def.affects_sim = def.affects_sim or m.affects_sim
		"remove":
			if not db.remove(StringName(id)):
				report.error(m.id, rel, "remove target '%s' does not exist" % id)
	for e in errors:
		report.error(m.id, rel, e)


func _put(m: ModManifest, rel: String, op: String, def: Def) -> void:
	var existing := db.get_def(def.id)
	if op == "add":
		if existing != null:
			report.error(m.id, rel, "'%s' already exists (from %s, %s); use op \"override\" or \"patch\"" \
					% [def.id, existing.source_mod, existing.source_file])
			return
		if DefIds.mod_of(def.id) != m.id:
			report.error(m.id, rel, "'%s': new IDs must use this mod's prefix '%s:'" % [def.id, m.id])
			return
	elif existing == null:
		report.error(m.id, rel, "override target '%s' does not exist" % def.id)
		return
	def.source_mod = StringName(m.id)
	def.source_file = rel
	def.affects_sim = m.affects_sim or (existing != null and existing.affects_sim)
	db.put(def)


## .tres Defs: allowed in core and in mods that declare has_scripts (loading a .tres can run code).
## The op comes from the resource metadata "op" (add or override); IDs inside must be full IDs.
func _load_tres(m: ModManifest, path: String, rel: String) -> void:
	if m.id != CORE_ID and not m.has_scripts:
		report.error(m.id, rel, ".tres files can run code; data-only mods must use .json (or set has_scripts)")
		return
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not res is Def:
		report.error(m.id, rel, "not a Def resource")
		return
	var def: Def = res.duplicate(true)
	var op := str(res.get_meta("op", "add"))
	if not op in ["add", "override"]:
		report.error(m.id, rel, ".tres Defs support op add or override, not '%s'" % op)
		return
	var id := DefIds.resolve_own(String(def.id), m.id, def.category())
	if id == "" or DefIds.category_of(id) != def.category():
		report.error(m.id, rel, "invalid id '%s' for category '%s'" % [def.id, def.category()])
		return
	def.id = StringName(id)
	_put(m, rel, op, def)


func _validate() -> void:
	var declared := {}
	for id: String in db.all_ids():
		var def := db.get_def(StringName(id))
		if def is ModifierKeyDef:
			var key := (def as ModifierKeyDef).key()
			if declared.has(key):
				report.error(String(def.source_mod), def.source_file, "modifier key '%s' is declared twice (also %s)" % [key, declared[key]])
			declared[key] = id
	for id: String in db.all_ids():
		var def := db.get_def(StringName(id))
		var errors := DefFactory.check(def, db, declared)
		if def is HullDef:
			errors.append_array(_check_hull_model(def))
		for e in errors:
			report.error(String(def.source_mod), def.source_file, "%s: %s" % [id, e])


## C6 hull/model check: every slot hardpoint must be a node in the hull's .glb.
func _check_hull_model(hull: HullDef) -> Array[String]:
	var errors: Array[String] = []
	if hull.model == "":
		return errors
	var path := resolve_model_path(hull.model, manifests.get(String(hull.source_mod)))
	var names := GlbReader.node_names(path, errors)
	if not errors.is_empty():
		return errors
	for s in hull.slots:
		if s.hardpoint != &"" and not String(s.hardpoint) in names:
			errors.append("hardpoint '%s' is not in %s" % [s.hardpoint, path])
	return errors


## Model paths are res:// paths, or relative to the mod folder, else to res:// (core's assets/).
static func resolve_model_path(model: String, manifest: ModManifest) -> String:
	if model.begins_with("res://") or model.begins_with("user://"):
		return model
	if manifest != null and FileAccess.file_exists(manifest.dir.path_join(model)):
		return manifest.dir.path_join(model)
	return "res://" + model


static func _def_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var subdirs := d.get_directories()
	subdirs.sort()
	for sub in subdirs:
		out.append_array(_def_files(dir.path_join(sub)))
	var files := d.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".json") or f.ends_with(".tres"):
			out.append(dir.path_join(f))
	return out
