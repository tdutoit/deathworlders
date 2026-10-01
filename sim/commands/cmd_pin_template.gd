class_name CmdPinTemplate
extends Command
## core:cmd/pin_template {"planet": id, "template": template Def ID, or "" to follow the directive} (D4)

const TYPE := &"core:cmd/pin_template"


func validate(state: MatchState) -> bool:
	var c := state.colony(p_int("planet"))
	if c == null or c.owner != player_id:
		return reject("planet %d is not your colony" % p_int("planet"))
	var t := str(payload.get("template", ""))
	if t != "" and not state.defs.get_def(StringName(t)) is TemplateDef:
		return reject("unknown template '%s'" % t)
	return true


func apply(state: MatchState) -> void:
	state.colony(p_int("planet")).pinned_template = str(payload.get("template", ""))
