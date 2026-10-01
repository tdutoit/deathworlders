class_name CmdSaveDesign
extends Command
## core:cmd/save_design {"name": text, "hull": hull Def ID, "components": [component IDs, "" = empty],
## "design": own design ID to replace (0 or absent = new)} (main spec 7.4: adding a design is a Command)

const TYPE := &"core:cmd/save_design"


func validate(state: MatchState) -> bool:
	if p_int("design", 0) != 0 and Designs.owned(state, player_id, p_int("design")) == null:
		return reject("design %d is not yours" % p_int("design"))
	var comps: Variant = payload.get("components", [])
	if not comps is Array:
		return reject("components must be a list")
	var reason := Designs.check(state, player_id, str(payload.get("name", "")), str(payload.get("hull", "")), comps)
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	Designs.save(state, player_id, p_int("design", 0), str(payload["name"]), str(payload["hull"]), payload["components"])
