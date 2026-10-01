class_name StateIO
extends RefCounted
## Helpers for entity to_dict / from_dict (M1 WP4). Dicts hold ints, strings, arrays and
## string-keyed dictionaries only, so they survive JSON. Values are re-cast on the way in.

const NONE := 0  # "no owner / no entity"; entity IDs start at 1


## IdMap of entities -> array of entity dicts in ID order.
static func map_to_array(m: IdMap) -> Array:
	var out := []
	for id: int in m:
		out.append(m.get_or(id).to_dict())
	return out


## Array of entity dicts -> IdMap keyed by "id", using factory(dict) -> entity.
static func array_to_map(items: Array, factory: Callable) -> IdMap:
	var m := IdMap.new()
	for d: Dictionary in items:
		var entity: Variant = factory.call(d)
		m.put(entity.id, entity)
	return m


static func ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in values:
		out.append(int(v))
	return out


## Dictionary with String keys and int values (e.g. deposits by resource ID).
static func int_map(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		out[String(k)] = int(d[k])
	return out
