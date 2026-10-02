class_name DefFactory
extends RefCounted
## Turns JSON-shaped dictionaries into Defs, applies patch ops, and checks Defs against their schema
## (Sub-spec C6). Pure data: input is already parsed, with every number an int (the loader rejects
## fractional numbers). Errors are appended as readable strings; callers add mod and file.

static var SCRIPTS := {  # class refs are not constant expressions
	"resource": ResourceDef,
	"planet_type": PlanetTypeDef,
	"star_type": StarTypeDef,
	"species": SpeciesDef,
	"match_preset": MatchPresetDef,
	"modifier_key": ModifierKeyDef,
	"name_list": NameListDef,
	"hull": HullDef,
	"job": JobDef,
	"building": BuildingDef,
	"focus": FocusDef,
	"synergy": SynergyDef,
	"station": StationDef,
	"directive": DirectiveDef,
	"template": TemplateDef,
	"start": StartDef,
	"economy_rules": EconomyRulesDef,
	"planet_size": PlanetSizeDef,
	"weapon_family": WeaponFamilyDef,
	"component": ComponentDef,
	"design": DesignDef,
	"combat_rules": CombatRulesDef,
	"trait": TraitDef,
	"diplomacy_rules": DiplomacyRulesDef,
	"treaty": TreatyDef,
}

const META_FIELDS: Array[String] = ["op", "category", "id"]
const PATCH_OPS: Array[String] = ["set", "add", "remove", "adjust"]

static var _color_re := RegEx.create_from_string("^#[0-9a-f]{6}$")


static func categories() -> Array:
	return SCRIPTS.keys()


static func create(category: String) -> Def:
	return SCRIPTS[category].new() if SCRIPTS.has(category) else null


## Builds a Def from {"category", "id", fields...}. Returns null if any error was added.
static func from_dict(data: Dictionary, own_mod: String, errors: Array[String]) -> Def:
	var category: String = str(data.get("category", ""))
	var def := create(category)
	if def == null:
		errors.append("unknown category '%s'" % category)
		return null
	var id := DefIds.resolve_own(str(data.get("id", "")), own_mod, category)
	if id == "" or DefIds.category_of(id) != category:
		errors.append("invalid id '%s' for category '%s'" % [data.get("id", ""), category])
		return null
	def.id = StringName(id)
	var before := errors.size()
	var schema := def.full_schema()
	for field: String in data:
		if field in META_FIELDS:
			continue
		if not schema.has(field):
			errors.append("%s: unknown field '%s'" % [id, field])
			continue
		var value: Variant = convert_value(data[field], schema[field], own_mod, "%s.%s" % [id, field], errors)
		if value != null:
			def.set(field, value)
	return def if errors.size() == before else null


## Converts one JSON value to the field's runtime type, or returns null and adds an error.
static func convert_value(v: Variant, spec: Dictionary, own_mod: String, where: String,
		errors: Array[String]) -> Variant:
	match spec["type"]:
		"int":
			if v is int:
				return v
		"bool":
			if v is bool:
				return v
		"string", "color":
			if v is String:
				return v
		"name", "enum":
			if v is String:
				return StringName(v)
		"scope":
			if v is String and v in ModifierDef.scope_names():
				return ModifierDef.scope_names().find(v)
			errors.append("%s: expected one of %s, got %s" % [where, ModifierDef.scope_names(), JSON.stringify(v)])
			return null
		"id":
			if v is String:
				return StringName() if v == "" else _ref(v, own_mod, where, errors)  # "" = no reference
		"id_list", "name_list":
			if v is Array:
				var out: Array[StringName] = []
				for item: Variant in v:
					if not item is String:
						errors.append("%s: list items must be strings" % where)
						return null
					var s: Variant
					if spec["type"] == "id_list":
						s = StringName() if item == "" and spec.get("allow_empty", false) else _ref(item, own_mod, where, errors)
					else:
						s = StringName(item)
					if s == null:
						return null
					out.append(s)
				return out
		"int_map":
			if v is Dictionary:
				var out := {}
				for k: String in v:
					if not v[k] is int:
						errors.append("%s.%s: expected int" % [where, k])
						return null
					var key: Variant = _ref(k, own_mod, where, errors) if spec.has("key_ref") else StringName(k)
					if key == null:
						return null
					out[key] = v[k]
				return out
		"int_list":
			if v is Array and v.all(func(item: Variant) -> bool: return item is int):
				var out: Array[int] = []
				out.assign(v)
				return out
		"string_list":
			if v is Array and v.all(func(item: Variant) -> bool: return item is String):
				var out: Array[String] = []
				out.assign(v)
				return out
		"slots":
			if v is Array:
				var out: Array[SlotDef] = []
				for item: Variant in v:
					var slot := _slot(item, where, errors)
					if slot == null:
						return null
					out.append(slot)
				return out
		"modifiers":
			if v is Array:
				var out: Array[ModifierDef] = []
				for item: Variant in v:
					var m := _modifier(item, where, errors)
					if m == null:
						return null
					out.append(m)
				return out
	errors.append("%s: expected %s, got %s" % [where, spec["type"], JSON.stringify(v)])
	return null


static func _ref(ref: String, own_mod: String, where: String, errors: Array[String]) -> Variant:
	var full := DefIds.resolve_ref(ref, own_mod)
	if full == "":
		errors.append("%s: malformed reference '%s'" % [where, ref])
		return null
	return StringName(full)


static func _slot(item: Variant, where: String, errors: Array[String]) -> SlotDef:
	if not item is Dictionary:
		errors.append("%s: each slot is an object {slot_type, slot_size, hardpoint}" % where)
		return null
	var s := SlotDef.new()
	var t := SlotDef.type_names().find(str(item.get("slot_type", "")))
	var z := SlotDef.size_names().find(str(item.get("slot_size", "")))
	if t < 0 or z < 0 or not item.get("hardpoint") is String:
		errors.append("%s: slot needs slot_type %s, slot_size %s and a hardpoint name" % [where, SlotDef.type_names(), SlotDef.size_names()])
		return null
	s.slot_type = t as SlotDef.SlotType
	s.slot_size = z as SlotDef.SlotSize
	s.hardpoint = StringName(item["hardpoint"])
	return s


static func _modifier(item: Variant, where: String, errors: Array[String]) -> ModifierDef:
	if not item is Dictionary or not item.get("key") is String:
		errors.append("%s: modifiers need at least {\"key\": \"...\"}" % where)
		return null
	var m := ModifierDef.new()
	m.key = StringName(item["key"])
	for field: String in item:
		match field:
			"key":
				pass
			"value":
				if not item["value"] is int:
					errors.append("%s: modifier value must be an int" % where)
					return null
				m.value = item["value"]
			"mode":
				var i := ModifierDef.mode_names().find(str(item["mode"]))
				if i < 0:
					errors.append("%s: modifier mode must be one of %s" % [where, ModifierDef.mode_names()])
					return null
				m.mode = i as ModifierDef.Mode
			"scope":
				var i := ModifierDef.scope_names().find(str(item["scope"]))
				if i < 0:
					errors.append("%s: modifier scope must be one of %s" % [where, ModifierDef.scope_names()])
					return null
				m.scope = i as ModifierDef.Scope
			"condition":
				if not item["condition"] is Dictionary:
					errors.append("%s: modifier condition must be an object" % where)
					return null
				m.condition = item["condition"]
			_:
				errors.append("%s: unknown modifier field '%s'" % [where, field])
				return null
	return m


## Applies {"set", "add", "remove", "adjust"} to def in place. Returns the fields that "set" changed
## (for conflict reporting).
static func apply_patch(def: Def, patch: Dictionary, own_mod: String, errors: Array[String]) -> Array[String]:
	var set_fields: Array[String] = []
	var schema := def.full_schema()
	for op: String in patch:
		if op in META_FIELDS:
			continue
		if not op in PATCH_OPS:
			errors.append("%s: unknown patch op '%s' (use %s)" % [def.id, op, PATCH_OPS])
			continue
		if not patch[op] is Dictionary:
			errors.append("%s: patch '%s' must be an object of fields" % [def.id, op])
			continue
		for field: String in patch[op]:
			if not schema.has(field):
				errors.append("%s: unknown field '%s'" % [def.id, field])
				continue
			var where := "%s.%s (%s)" % [def.id, field, op]
			var spec: Dictionary = schema[field]
			var arg: Variant = patch[op][field]
			match op:
				"set":
					var value: Variant = convert_value(arg, spec, own_mod, where, errors)
					if value != null:
						def.set(field, value)
						set_fields.append(field)
				"add":
					_patch_add(def, field, spec, arg, own_mod, where, errors)
				"remove":
					_patch_remove(def, field, spec, arg, own_mod, where, errors)
				"adjust":
					_patch_adjust(def, field, spec, arg, own_mod, where, errors)
	return set_fields


static func _patch_add(def: Def, field: String, spec: Dictionary, arg: Variant, own_mod: String,
		where: String, errors: Array[String]) -> void:
	var t: String = spec["type"]
	if not t in ["id_list", "name_list", "string_list", "modifiers", "int_map"]:
		errors.append("%s: 'add' works on lists and maps, not %s" % [where, t])
		return
	var items: Variant = convert_value(arg, spec, own_mod, where, errors)
	if items == null:
		return
	if t == "int_map":
		var current: Dictionary = def.get(field)
		current.merge(items, true)
		return
	var current: Array = def.get(field)
	for item: Variant in items:
		if t == "modifiers" or not item in current:
			current.append(item)


static func _patch_remove(def: Def, field: String, spec: Dictionary, arg: Variant, own_mod: String,
		where: String, errors: Array[String]) -> void:
	var t: String = spec["type"]
	if not arg is Array:
		errors.append("%s: 'remove' takes a list" % where)
		return
	if t == "modifiers":
		var current: Array[ModifierDef] = def.get(field)
		for key: Variant in arg:
			var keep: Array[ModifierDef] = []
			for m in current:
				if String(m.key) != str(key):
					keep.append(m)
			current = keep
		def.set(field, current)
		return
	if not t in ["id_list", "name_list", "string_list", "int_map"]:
		errors.append("%s: 'remove' works on lists and maps, not %s" % [where, t])
		return
	var keyed := t == "id_list" or (t == "int_map" and spec.has("key_ref"))
	var current: Variant = def.get(field)
	for item: Variant in arg:
		if not item is String:
			errors.append("%s: 'remove' items must be strings" % where)
			return
		var key: Variant = _ref(item, own_mod, where, errors) if keyed else (item if t == "string_list" else StringName(item))
		if key == null:
			return
		current.erase(key)


static func _patch_adjust(def: Def, field: String, spec: Dictionary, arg: Variant, own_mod: String,
		where: String, errors: Array[String]) -> void:
	match spec["type"]:
		"int":
			if arg is int:
				def.set(field, def.get(field) + arg)
				return
		"int_map":
			var deltas: Variant = convert_value(arg, spec, own_mod, where, errors)
			if deltas == null:
				return
			var current: Dictionary = def.get(field)
			for k: Variant in deltas:
				current[k] = current.get(k, 0) + deltas[k]
			return
	errors.append("%s: 'adjust' takes an int delta (or a map of deltas)" % where)


## Schema, reference and modifier-key checks on a Def inside the full database, plus the Def's own
## validate(). declared_keys: modifier key -> true.
static func check(def: Def, db: DefDatabase, declared_keys: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema := def.full_schema()
	for field: String in schema:
		_check_field(def.get(field), schema[field], db, declared_keys, field, errors)
	errors.append_array(def.validate(db))
	return errors


static func _check_field(v: Variant, spec: Dictionary, db: DefDatabase, declared_keys: Dictionary,
		field: String, errors: Array[String]) -> void:
	var t: String = spec["type"]
	var required: bool = spec.get("required", false)
	match t:
		"int":
			_check_range(v, spec, field, errors)
		"string", "name":
			if required and String(v) == "":
				errors.append("%s is required" % field)
		"color":
			if required and String(v) == "":
				errors.append("%s is required" % field)
			elif String(v) != "" and _color_re.search(String(v)) == null:
				errors.append("%s must be a lowercase \"#rrggbb\" colour, got '%s'" % [field, v])
		"enum":
			if String(v) == "":
				if required:
					errors.append("%s is required (one of %s)" % [field, spec["values"]])
			elif not String(v) in spec["values"]:
				errors.append("%s must be one of %s, got '%s'" % [field, spec["values"], v])
		"id":
			if String(v) == "":
				if required:
					errors.append("%s is required" % field)
			else:
				_check_ref(v, spec["ref"], db, field, errors)
		"string_list", "name_list":
			if required and (v as Array).is_empty():
				errors.append("%s needs at least one entry" % field)
		"id_list":
			for item: StringName in v:
				if item == &"" and spec.get("allow_empty", false):
					continue  # an empty entry (e.g. an empty design slot)
				_check_ref(item, spec["ref"], db, field, errors)
		"int_list":
			if spec.has("size") and (v as Array).size() != spec["size"]:
				errors.append("%s needs exactly %d values, got %d" % [field, spec["size"], (v as Array).size()])
			for i in (v as Array).size():
				_check_range(v[i], spec, "%s[%d]" % [field, i], errors)
		"int_map":
			for k: Variant in v:
				if spec.has("key_ref"):
					_check_ref(k, spec["key_ref"], db, field, errors)
				elif spec.has("keys") and not String(k) in spec["keys"]:
					errors.append("%s: unknown key '%s' (allowed: %s)" % [field, k, spec["keys"]])
				_check_range(v[k], spec, "%s[%s]" % [field, k], errors)
		"modifiers":
			for m: ModifierDef in v:
				if not declared_keys.has(m.key):
					errors.append("%s: modifier key '%s' is not declared by any modifier_key Def" % [field, m.key])


static func _check_range(v: int, spec: Dictionary, field: String, errors: Array[String]) -> void:
	if spec.has("min") and v < spec["min"]:
		errors.append("%s must be >= %d, got %d" % [field, spec["min"], v])
	if spec.has("max") and v > spec["max"]:
		errors.append("%s must be <= %d, got %d" % [field, spec["max"], v])


static func _check_ref(ref: StringName, category: String, db: DefDatabase, field: String,
		errors: Array[String]) -> void:
	if DefIds.category_of(ref) != category:
		errors.append("%s: '%s' is not a %s ID" % [field, ref, category])
	elif not db.has(ref):
		errors.append("%s: '%s' does not exist" % [field, ref])
