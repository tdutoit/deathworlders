class_name CmdSetDirective
extends Command
## core:cmd/set_directive {"sector": id, "directive": directive Def ID} (Sub-spec D3)

const TYPE := &"core:cmd/set_directive"


func validate(state: MatchState) -> bool:
	var sec: Sector = state.sectors.get_or(p_int("sector"))
	if sec == null or sec.owner != player_id:
		return reject("sector %d is not yours" % p_int("sector"))
	if not state.defs.get_def(StringName(str(payload.get("directive", "")))) is DirectiveDef:
		return reject("unknown directive '%s'" % payload.get("directive", ""))
	return true


func apply(state: MatchState) -> void:
	(state.sectors.get_or(p_int("sector")) as Sector).directive = str(payload["directive"])
