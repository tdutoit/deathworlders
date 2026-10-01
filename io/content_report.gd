class_name ContentReport
extends RefCounted
## Errors and warnings from loading content. Every entry names the mod and file (Sub-spec C6).

var load_order: Array[String] = []
var entries: Array[Dictionary] = []  # {severity, mod, file, message}


func error(mod_id: String, file: String, message: String) -> void:
	entries.append({"severity": "ERROR", "mod": mod_id, "file": file, "message": message})


func warning(mod_id: String, file: String, message: String) -> void:
	entries.append({"severity": "WARNING", "mod": mod_id, "file": file, "message": message})


func errors() -> Array[Dictionary]:
	return _with_severity("ERROR")


func warnings() -> Array[Dictionary]:
	return _with_severity("WARNING")


func _with_severity(severity: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		if e["severity"] == severity:
			out.append(e)
	return out


func has_errors() -> bool:
	return not errors().is_empty()


## True if some error's message contains every given fragment (used by tests).
func has_error_containing(fragments: Array) -> bool:
	for e in errors():
		var text := format_entry(e)
		if fragments.all(func(f: String) -> bool: return text.contains(f)):
			return true
	return false


static func format_entry(e: Dictionary) -> String:
	var where: String = e["mod"]
	if e["file"] != "":
		where += " (%s)" % e["file"]
	return "[%s] %s: %s" % [e["severity"], where, e["message"]]


func format_text() -> String:
	var lines := PackedStringArray()
	lines.append("Content load order: %s" % ", ".join(load_order))
	for e in entries:
		lines.append(format_entry(e))
	lines.append("%d error(s), %d warning(s)" % [errors().size(), warnings().size()])
	return "\n".join(lines)
