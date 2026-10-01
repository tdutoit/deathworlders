class_name SaveGame
extends RefCounted
## Save files (Sub-spec C12): deflate-compressed JSON with a header, the full MatchState and the
## pending lockstep commands. Loading refuses mismatched content (content_hash) or missing
## sim-affecting mods, with a readable list.

const FORMAT := 1
const LOG_TAIL := 100  # command_log_tail entries kept in the header for desync debugging
const DIR := "user://saves"
const EXT := ".sav"
const AUTOSAVES := 3

var state: MatchState
var pending: Array = []  # CommandSchedule.to_array() at save time
var header := {}
var errors: Array[String] = []


## Writes state (and pending commands) to path. Returns an error string or "".
static func write(path: String, s: MatchState, schedule: CommandSchedule, db: DefDatabase, manifests: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var d := s.to_dict()
	var mods := []
	for id: String in IdMap.sort_keys(manifests.keys()):
		var m: ModManifest = manifests[id]
		mods.append({"id": m.id, "version": m.version, "affects_sim": m.affects_sim})
	var data := {
		"save_format": FORMAT,
		"game_version": ContentLoader.game_version(),
		"content_hash": "%08x" % db.content_hash,
		"mods": mods,
		"settings": d["settings"],
		"match_seed": s.match_seed,
		"tick": s.tick,
		"rng_states": d["rng_streams"],
		"state": d,
		"pending_commands": schedule.to_array() if schedule else [],
		"command_log_tail": s.command_log.slice(maxi(0, s.command_log.size() - LOG_TAIL)),
	}
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_DEFLATE)
	if f == null:
		return "cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	f.store_string(JSON.stringify(data))
	f.close()
	return ""


## Reads a save. Check `errors` first; on success `state` and `pending` are set.
static func read(path: String, db: DefDatabase, manifests: Dictionary) -> SaveGame:
	var out := SaveGame.new()
	var data := _read_json(path, out.errors)
	if data.is_empty():
		return out
	out.header = data
	if int(data.get("save_format", 0)) != FORMAT:
		out.errors.append("unsupported save format %s (this game reads %d)" % [data.get("save_format"), FORMAT])
		return out
	var missing := []
	for m: Dictionary in data.get("mods", []):
		if m.get("affects_sim", true) and not manifests.has(m["id"]):
			missing.append("%s %s" % [m["id"], m["version"]])
	if not missing.is_empty():
		out.errors.append("missing mods: " + ", ".join(missing))
	if str(data.get("content_hash", "")) != "%08x" % db.content_hash:
		out.errors.append("content differs from this save (content hash %s, loaded %08x); enable the same mods" \
				% [data.get("content_hash"), db.content_hash])
	if not out.errors.is_empty():
		return out
	out.state = MatchState.from_dict(data["state"])
	out.pending = data.get("pending_commands", [])
	return out


## Just the header fields, for the load list (no state rebuild).
static func peek(path: String) -> Dictionary:
	var errors: Array[String] = []
	var data := _read_json(path, errors)
	data.erase("state")
	return data


static func _read_json(path: String, errors: Array[String]) -> Dictionary:
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_DEFLATE)
	if f == null:
		errors.append("cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK or not json.data is Dictionary:
		errors.append("%s is not a valid save (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data


## Saves in dir, newest first: [{path, name, modified}].
static func list_saves(dir := DIR) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(EXT):
			var path := dir.path_join(f)
			out.append({"path": path, "name": f.trim_suffix(EXT), "modified": FileAccess.get_modified_time(path)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["modified"] > b["modified"] if a["modified"] != b["modified"] else a["name"] < b["name"])
	return out


## Rolling autosave slot for a month tick: autosave_1 .. autosave_3.
static func autosave_path(tick: int) -> String:
	@warning_ignore("integer_division")
	var month := tick / Calendar.HOURS_PER_MONTH
	return DIR.path_join("autosave_%d%s" % [month % AUTOSAVES + 1, EXT])
