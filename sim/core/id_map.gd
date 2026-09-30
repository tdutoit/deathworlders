class_name IdMap
extends RefCounted
## Dictionary that always iterates in sorted key order (M1 WP2). Use it for every entity
## collection in sim state; raw Dictionary order depends on insertion history.
##
## Keys are all int or all String within one map. `for key in id_map` walks keys ascending.
## Don't add or erase keys while iterating; loop over keys() (a copy) instead.

var _data: Dictionary = {}
var _sorted_keys: Array = []
var _dirty := false
var _key_type: int = TYPE_NIL


## Sorts keys deterministically: by Variant type first, then value (Strings by code point).
static func sort_keys(keys: Array) -> Array:
	var out := keys.duplicate()
	out.sort_custom(_key_less)
	return out


static func _key_less(a: Variant, b: Variant) -> bool:
	if a is StringName:
		a = String(a)
	if b is StringName:
		b = String(b)
	if typeof(a) != typeof(b):
		return typeof(a) < typeof(b)
	return a < b


func put(key: Variant, value: Variant) -> void:
	assert(key is int or key is String, "IdMap keys must be int or String")
	if _data.is_empty():
		_key_type = typeof(key)
	assert(typeof(key) == _key_type, "IdMap keys must share one type")
	if not _data.has(key):
		_dirty = true
	_data[key] = value


func get_or(key: Variant, default: Variant = null) -> Variant:
	return _data.get(key, default)


func has(key: Variant) -> bool:
	return _data.has(key)


func erase(key: Variant) -> bool:
	var removed := _data.erase(key)
	if removed:
		_dirty = true
	return removed


func clear() -> void:
	_data.clear()
	_sorted_keys.clear()
	_dirty = false


func size() -> int:
	return _data.size()


func is_empty() -> bool:
	return _data.is_empty()


## Sorted copy of the keys.
func keys() -> Array:
	return _keys().duplicate()


## Values in sorted key order.
func values() -> Array:
	var out := []
	for key: Variant in _keys():
		out.append(_data[key])
	return out


func _keys() -> Array:
	if _dirty:
		_sorted_keys = sort_keys(_data.keys())
		_dirty = false
	return _sorted_keys


func _iter_init(iter: Array) -> bool:
	iter[0] = 0
	return not _keys().is_empty()


func _iter_next(iter: Array) -> bool:
	iter[0] += 1
	return iter[0] < _keys().size()


func _iter_get(iter: Variant) -> Variant:
	return _keys()[iter]
