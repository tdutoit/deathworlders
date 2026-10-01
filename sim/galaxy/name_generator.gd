class_name NameGenerator
extends RefCounted
## Unique star and cluster names from NameListDef syllables (all lists merged, in ID order).

const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]

var _rng: DetRng
var _starts: Array[String] = []
var _middles: Array[String] = []
var _ends: Array[String] = []
var _suffixes: Array[String] = []
var _used := {}


func _init(db: DefDatabase, rng: DetRng) -> void:
	_rng = rng
	for def in db.defs("name_list"):
		var list: NameListDef = def
		_starts.append_array(list.starts)
		_middles.append_array(list.middles)
		_ends.append_array(list.ends)
		_suffixes.append_array(list.cluster_suffixes)


func reserve(name: String) -> void:
	_used[name] = true


func star_name() -> String:
	for attempt in 50:
		var name := _pick(_starts)
		if not _middles.is_empty() and _rng.range(0, 3) == 0:
			name += _pick(_middles)
		name += _pick(_ends)
		if not _used.has(name):
			_used[name] = true
			return name
	# Syllables exhausted: number the name instead.
	var base := _pick(_starts) + _pick(_ends)
	var n := 2
	while _used.has("%s %d" % [base, n]):
		n += 1
	_used["%s %d" % [base, n]] = true
	return "%s %d" % [base, n]


func cluster_name() -> String:
	var base := star_name()
	return base + " " + _pick(_suffixes) if not _suffixes.is_empty() else base


static func planet_name(system_name: String, orbit_index: int) -> String:
	var numeral := ROMAN[orbit_index] if orbit_index < ROMAN.size() else str(orbit_index + 1)
	return system_name + " " + numeral


func _pick(list: Array[String]) -> String:
	return list[_rng.range(0, list.size())] if not list.is_empty() else "X"
