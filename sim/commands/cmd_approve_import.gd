class_name CmdApproveImport
extends Command
## core:cmd/approve_import {"holder": id, "resource": ID, "amount": units} (Sub-spec D5)
## Approves a sector's import request: a Critical demand at the holder, fillable from anywhere (trunk).

const TYPE := &"core:cmd/approve_import"


func validate(state: MatchState) -> bool:
	if Holders.owner(state, p_int("holder")) != player_id:
		return reject("holder %d is not your colony or station" % p_int("holder"))
	var res := state.defs.get_def(StringName(str(payload.get("resource", "")))) as ResourceDef
	if res == null or not res.physical:
		return reject("'%s' is not a physical resource" % payload.get("resource", ""))
	if p_int("amount") <= 0:
		return reject("amount must be positive")
	return true


func apply(state: MatchState) -> void:
	var res := str(payload["resource"])
	var d := CmdSetDemandTarget.find(state, player_id, p_int("holder"), res)
	if d == null:
		d = Demand.new()
		d.id = state.alloc_id()
		d.owner = player_id
		d.holder = p_int("holder")
		d.resource = res
		state.demands.put(d.id, d)
	d.target = Holders.stockpile(state, d.holder).units(res) + p_int("amount")
	d.priority = 3
