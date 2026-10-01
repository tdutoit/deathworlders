class_name SlotDef
extends Resource
## One fixed hull slot (Sub-spec C5). hardpoint names the empty in the hull .glb (C11):
## HP_<W|D|U|C|H>_<S|M|L>_<NN>, and its letters must match slot_type and slot_size.

enum SlotType { WEAPON, DEFENCE, UTILITY, CORE, HANGAR }
enum SlotSize { S, M, L }

const TYPE_LETTERS := "WDUCH"

@export var slot_type: SlotType = SlotType.WEAPON
@export var slot_size: SlotSize = SlotSize.S
@export var hardpoint: StringName  # "HP_W_S_01"


func to_dict() -> Dictionary:
	return {"slot_type": slot_type, "slot_size": slot_size, "hardpoint": hardpoint}


## "HP_W_S" for a small weapon slot.
func expected_prefix() -> String:
	return "HP_%s_%s" % [TYPE_LETTERS[slot_type], SlotSize.keys()[slot_size]]


static func type_names() -> PackedStringArray:
	var out := PackedStringArray()
	for n: String in SlotType.keys():
		out.append(n.to_lower())
	return out


static func size_names() -> PackedStringArray:
	return PackedStringArray(SlotSize.keys())
