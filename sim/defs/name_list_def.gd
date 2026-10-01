class_name NameListDef
extends Def
## Syllables for generated star and cluster names (M1 WP7). A name is start + end, or
## start + middle + end; clusters add a suffix ("Varos Reach"). Mods can add lists or patch syllables.

@export var starts: Array[String] = []
@export var middles: Array[String] = []
@export var ends: Array[String] = []
@export var cluster_suffixes: Array[String] = []


func category() -> String:
	return "name_list"


func schema() -> Dictionary:
	return {
		"starts": {"type": "string_list", "required": true},
		"middles": {"type": "string_list"},
		"ends": {"type": "string_list", "required": true},
		"cluster_suffixes": {"type": "string_list", "required": true},
	}
