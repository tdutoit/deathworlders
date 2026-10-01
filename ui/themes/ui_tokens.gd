class_name UiTokens
extends RefCounted
## Control Room colour tokens (Sub-spec F21) from ui/themes/tokens.json. Views and the UI theme both
## read colours from here so the light/dark palettes (and mods) swap in one place.

const PATH := "res://ui/themes/tokens.json"

static var palette := "light"
static var _cache := {}


static func color(token: String) -> Color:
	if _cache.is_empty():
		_cache = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return Color.html(_cache[palette][token])
