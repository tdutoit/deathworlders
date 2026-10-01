class_name CmdSetExportQuota
extends Command
## core:cmd/set_export_quota {"sector": id, "resource": ID, "permille": 0-1000} (Sub-spec D5)
## The share of the sector hub's surplus sent up the trunk to the Core hub. -1 restores the default.

const TYPE := &"core:cmd/set_export_quota"


func validate(state: MatchState) -> bool:
	var sec: Sector = state.sectors.get_or(p_int("sector"))
	if sec == null or sec.owner != player_id:
		return reject("sector %d is not yours" % p_int("sector"))
	var res := state.defs.get_def(StringName(str(payload.get("resource", "")))) as ResourceDef
	if res == null or not res.physical:
		return reject("'%s' is not a physical resource" % payload.get("resource", ""))
	if p_int("permille", -2) < -1 or p_int("permille") > 1000:
		return reject("permille must be 0-1000 (or -1 for the default)")
	return true


func apply(state: MatchState) -> void:
	var sec: Sector = state.sectors.get_or(p_int("sector"))
	if p_int("permille") < 0:
		sec.export_quotas.erase(str(payload["resource"]))
	else:
		sec.export_quotas[str(payload["resource"])] = p_int("permille")
