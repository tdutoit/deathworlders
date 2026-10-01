class_name DefDatabase
extends RefCounted
## All loaded Defs, keyed by string ID (Sub-spec C1, C6). Filled by the content loader, then frozen.
## After freeze: read-only, per-category sorted ID lists, dense int indices (never saved or sent)
## and content_hash over every affects_sim Def in ID order.

var content_hash := 0

var _defs := IdMap.new()  # String id -> Def
var _frozen := false
var _by_category := {}  # category -> Array of ids, sorted
var _index := {}  # id -> dense index within its category


func is_frozen() -> bool:
	return _frozen


func has(id: StringName) -> bool:
	return _defs.has(String(id))


func get_def(id: StringName) -> Def:
	return _defs.get_or(String(id))


func size() -> int:
	return _defs.size()


## Every ID in sorted order.
func all_ids() -> Array:
	return _defs.keys()


## Sorted IDs of one category (empty if none).
func ids(category: String) -> Array:
	assert(_frozen, "DefDatabase.ids: freeze first")
	return _by_category.get(category, []).duplicate()


func defs(category: String) -> Array[Def]:
	var out: Array[Def] = []
	for id: String in ids(category):
		out.append(_defs.get_or(id))
	return out


## Dense index of id within its category, or -1. Runtime only: never save or send it.
func index_of(id: StringName) -> int:
	assert(_frozen, "DefDatabase.index_of: freeze first")
	return _index.get(String(id), -1)


func id_at(category: String, index: int) -> StringName:
	assert(_frozen, "DefDatabase.id_at: freeze first")
	return StringName(_by_category[category][index])


## Adds or replaces a Def (loader only, before freeze).
func put(def: Def) -> void:
	assert(not _frozen, "DefDatabase is frozen")
	_defs.put(String(def.id), def)


func remove(id: StringName) -> bool:
	assert(not _frozen, "DefDatabase is frozen")
	return _defs.erase(String(id))


func freeze() -> void:
	assert(not _frozen, "DefDatabase already frozen")
	_by_category.clear()
	_index.clear()
	var h := DetHash.OFFSET
	for id: String in _defs:
		var def: Def = _defs.get_or(id)
		var category := def.category()
		if not _by_category.has(category):
			_by_category[category] = []
		_index[id] = _by_category[category].size()
		_by_category[category].append(id)
		if def.affects_sim:
			h = DetHash.hash_value(def.to_dict(), h)
	content_hash = h
	_frozen = true
