class_name DesignLibrary
extends RefCounted
## The player's personal design library across matches (main spec 7.4): one C5 design JSON per file in
## user://designs/. Purely local; designs enter a match through CmdSaveDesign.

const DIR := "user://designs"
const EXT := ".json"


static func save(name: String, hull: String, components: Array, dir := DIR) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(_file_name(name) + EXT)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	f.store_string(JSON.stringify(DesignCode.to_json_dict(name, hull, components), "\t"))
	f.close()
	return ""


## Every readable design file, sorted by file name: [{"file", "data"}].
static func list(dir := DIR) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var files := Array(d.get_files()).filter(func(f: String) -> bool: return f.ends_with(EXT))
	files.sort()
	for f: String in files:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		if data is Dictionary:
			out.append({"file": f, "data": data})
	return out


static func remove(file: String, dir := DIR) -> void:
	DirAccess.remove_absolute(dir.path_join(file))


## A safe file name from a design name: letters, digits, '-' and '_' only.
static func _file_name(name: String) -> String:
	var out := ""
	for ch in name.strip_edges().to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "-" else "_"
	return out if out != "" else "design"
