class_name GlbReader
extends RefCounted
## Reads node names from a binary glTF (.glb) without importing it: header + first (JSON) chunk.
## Used by content validation to check hull hardpoints (Sub-spec C6/C11).

const MAGIC := 0x46546C67  # "glTF"
const CHUNK_JSON := 0x4E4F534A  # "JSON"


## Node names in the file, or [] with an error appended if it isn't a readable .glb.
static func node_names(path: String, errors: Array[String]) -> PackedStringArray:
	var out := PackedStringArray()
	if not FileAccess.file_exists(path):
		errors.append("model '%s' not found" % path)
		return out
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 20 or bytes.decode_u32(0) != MAGIC or bytes.decode_u32(16) != CHUNK_JSON:
		errors.append("'%s' is not a binary glTF (.glb)" % path)
		return out
	var json_len := bytes.decode_u32(12)
	var json: Variant = JSON.parse_string(bytes.slice(20, 20 + json_len).get_string_from_utf8())
	if not json is Dictionary:
		errors.append("'%s' has an unreadable glTF JSON chunk" % path)
		return out
	for node: Dictionary in json.get("nodes", []):
		out.append(str(node.get("name", "")))
	return out
