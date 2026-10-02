class_name CmdSetWarFooting
extends Command
## core:cmd/set_war_footing {"footing": war_footing Def ID} (Sub-spec D7).

const TYPE := &"core:cmd/set_war_footing"


func validate(state: MatchState) -> bool:
	var f := str(payload.get("footing", ""))
	if not state.defs.get_def(StringName(f)) is WarFootingDef:
		return reject("unknown war footing %s" % f)
	if state.empire(player_id).footing == f:
		return reject("already on that footing")
	return true


func apply(state: MatchState) -> void:
	WarFooting.change(state, state.empire(player_id), str(payload["footing"]))
