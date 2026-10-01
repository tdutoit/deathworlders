class_name DesignCode
extends RefCounted
## Ship design sharing (main spec 7.4, Sub-spec C5): a design as JSON
## {"format", "name", "hull", "slots", "mods_required"}, and the short text code base64(deflate(json)).
## Import reports missing mod content and rejects wrong-species hulls; adding the design to an empire is
## then a normal CmdSaveDesign.

const FORMAT := 1
const MAX_JSON := 65536  # decompression bound for a pasted code

static var _base64_re := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")


## The C5 JSON form of a design (ShipDesign or any {name, hull, components}).
static func to_json_dict(name: String, hull: String, components: Array) -> Dictionary:
	var mods := {}
	for id: Variant in [hull] + components:
		var s := String(id)
		if s != "" and s.get_slice(":", 0) != "core":
			mods[s.get_slice(":", 0)] = true
	return {"format": FORMAT, "name": name, "hull": hull, "slots": components.duplicate(),
		"mods_required": IdMap.sort_keys(mods.keys())}


static func encode(name: String, hull: String, components: Array) -> String:
	var bytes := JSON.stringify(to_json_dict(name, hull, components)).to_utf8_buffer()
	return Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE))


## Decodes a pasted code. Returns {"name", "hull", "components", "errors": [...], "missing_mods": [...]};
## the design is usable only when both lists are empty.
static func decode(code: String, db: DefDatabase, species: String) -> Dictionary:
	var out := {"name": "", "hull": "", "components": [], "errors": [], "missing_mods": []}
	var text := code.strip_edges()
	if text == "" or text.length() % 4 != 0 or _base64_re.search(text) == null:
		out["errors"].append("not a design code")  # checked first: the engine logs an error on bad base64
		return out
	var raw := Marshalls.base64_to_raw(text)
	var bytes := raw.decompress_dynamic(MAX_JSON, FileAccess.COMPRESSION_DEFLATE) if not raw.is_empty() else PackedByteArray()
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8()) if not bytes.is_empty() else null
	if not data is Dictionary:
		out["errors"].append("not a design code")
		return out
	return from_json_dict(data, db, species)


## Checks a C5 design JSON against the loaded content and the importing empire's species.
static func from_json_dict(data: Dictionary, db: DefDatabase, species: String) -> Dictionary:
	var out := {"name": "", "hull": "", "components": [], "errors": [], "missing_mods": []}
	if int(data.get("format", 0)) != FORMAT:
		out["errors"].append("unsupported design format %s" % str(data.get("format", "?")))
		return out
	out["name"] = str(data.get("name", ""))
	out["hull"] = str(data.get("hull", ""))
	var slots: Variant = data.get("slots", [])
	if not slots is Array or not (slots as Array).all(func(x: Variant) -> bool: return x is String):
		out["errors"].append("slots must be a list of component IDs")
		return out
	out["components"] = slots
	var missing := {}
	for id: String in [out["hull"]] + slots:
		if id != "" and db.get_def(StringName(id)) == null:
			missing[id.get_slice(":", 0)] = true
	for m: String in data.get("mods_required", []):
		if not missing.has(m) and _mod_absent(db, m):
			missing[m] = true
	out["missing_mods"] = IdMap.sort_keys(missing.keys())
	if not missing.is_empty():
		return out
	var h := db.get_def(StringName(out["hull"])) as HullDef
	if h == null or h.role != &"warship":
		out["errors"].append("%s is not a warship hull" % out["hull"])
	elif h.species != &"" and String(h.species) != species:
		out["errors"].append("this design is for %s ships" % h.species)
	else:
		out["errors"].append_array(DesignDef.check_fit(h, slots, db))
	return out


## True if no loaded Def comes from that mod prefix.
static func _mod_absent(db: DefDatabase, mod: String) -> bool:
	for cat in ["hull", "component"]:
		for id: StringName in db.ids(cat):
			if String(id).begins_with(mod + ":"):
				return false
	return true
