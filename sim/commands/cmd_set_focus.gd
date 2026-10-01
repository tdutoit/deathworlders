class_name CmdSetFocus
extends Command
## core:cmd/set_focus {"planet": id, "primary": focus Def ID, "secondary": focus Def ID}
## Changing either focus starts retooling (B4: 180 days at Standard pace, affected jobs -300 permille).

const TYPE := &"core:cmd/set_focus"


func validate(state: MatchState) -> bool:
	var c := state.colony(p_int("planet"))
	if c == null or c.owner != player_id:
		return reject("planet %d is not your colony" % p_int("planet"))
	var primary := str(payload.get("primary", ""))
	var secondary := str(payload.get("secondary", ""))
	for f in [primary, secondary]:
		if not state.defs.get_def(StringName(f)) is FocusDef:
			return reject("unknown focus '%s'" % f)
	if primary == secondary:
		return reject("Primary and Secondary focus must differ")
	if primary == c.primary_focus and secondary == c.secondary_focus:
		return reject("focus unchanged")
	return true


func apply(state: MatchState) -> void:
	var c := state.colony(p_int("planet"))
	c.primary_focus = str(payload["primary"])
	c.secondary_focus = str(payload["secondary"])
	c.retool_days = Pace.scale(Economy.rules(state.defs).retool_days, BuildRules.pace(state))
	Economy.assign_jobs(c, state.defs)
