class_name DefIds
extends RefCounted
## Content ID rules (Sub-spec C1): "<mod_id>:<category>/<name>".
## mod_id and category are [a-z0-9_]; names also allow "." (modifier keys like "planet.housing").

static var _full_re := RegEx.create_from_string("^[a-z0-9_]+:[a-z0-9_]+/[a-z0-9_.]+$")
static var _mod_re := RegEx.create_from_string("^[a-z0-9_]+$")


static func is_valid_mod_id(mod_id: String) -> bool:
	return _mod_re.search(mod_id) != null


static func is_full(id: String) -> bool:
	return _full_re.search(id) != null


static func mod_of(id: String) -> String:
	return id.get_slice(":", 0)


static func category_of(id: String) -> String:
	return id.get_slice(":", 1).get_slice("/", 0)


## Resolves a reference written inside own_mod. Accepts "mod:category/name" or "category/name"
## (same mod). Returns "" if the result is not a well-formed ID.
static func resolve_ref(ref: String, own_mod: String) -> String:
	var full := ref if ref.contains(":") else own_mod + ":" + ref
	return full if is_full(full) else ""


## Resolves a Def's own "id" field, which may also be a bare name when the category is known.
static func resolve_own(id: String, own_mod: String, category: String) -> String:
	if not id.contains("/") and not id.contains(":"):
		id = category + "/" + id
	return resolve_ref(id, own_mod)
