class_name CommandRegistry
extends RefCounted
## type_id -> Command class (Sub-spec C7). Rebuilds Commands from logs and network messages.

static var _types := {  # class refs are not constant expressions
	CmdPause.TYPE: CmdPause,
	CmdSetSpeed.TYPE: CmdSetSpeed,
	CmdMoveUnit.TYPE: CmdMoveUnit,
	CmdDebugSpawnScout.TYPE: CmdDebugSpawnScout,
	CmdQueueBuilding.TYPE: CmdQueueBuilding,
	CmdQueueStation.TYPE: CmdQueueStation,
	CmdUpgradeStation.TYPE: CmdUpgradeStation,
	CmdCancelConstruction.TYPE: CmdCancelConstruction,
	CmdSetFocus.TYPE: CmdSetFocus,
	CmdQueueShip.TYPE: CmdQueueShip,
	CmdRebaseFreighter.TYPE: CmdRebaseFreighter,
	CmdCreateRoute.TYPE: CmdCreateRoute,
	CmdEditRoute.TYPE: CmdEditRoute,
	CmdDeleteRoute.TYPE: CmdDeleteRoute,
	CmdAssignFreighter.TYPE: CmdAssignFreighter,
	CmdSetDemandTarget.TYPE: CmdSetDemandTarget,
	CmdSetReserve.TYPE: CmdSetReserve,
	CmdCreateSector.TYPE: CmdCreateSector,
	CmdSetDirective.TYPE: CmdSetDirective,
	CmdSetAutonomy.TYPE: CmdSetAutonomy,
	CmdPinTemplate.TYPE: CmdPinTemplate,
	CmdApproveSuggestion.TYPE: CmdApproveSuggestion,
	CmdSetExportQuota.TYPE: CmdSetExportQuota,
	CmdApproveImport.TYPE: CmdApproveImport,
	CmdColonise.TYPE: CmdColonise,
	CmdSaveDesign.TYPE: CmdSaveDesign,
	CmdDeleteDesign.TYPE: CmdDeleteDesign,
	CmdCreateFleet.TYPE: CmdCreateFleet,
	CmdMergeFleets.TYPE: CmdMergeFleets,
	CmdSplitFleet.TYPE: CmdSplitFleet,
	CmdRenameFleet.TYPE: CmdRenameFleet,
	CmdMoveFleet.TYPE: CmdMoveFleet,
	CmdSetDoctrine.TYPE: CmdSetDoctrine,
	CmdMoveSquadron.TYPE: CmdMoveSquadron,
	CmdDeclareWar.TYPE: CmdDeclareWar,
	CmdMakePeace.TYPE: CmdMakePeace,
	CmdSetEscort.TYPE: CmdSetEscort,
	CmdProposeTreaty.TYPE: CmdProposeTreaty,
	CmdAnswerProposal.TYPE: CmdAnswerProposal,
	CmdCancelTreaty.TYPE: CmdCancelTreaty,
	CmdAnswerCall.TYPE: CmdAnswerCall,
	CmdProposeDeal.TYPE: CmdProposeDeal,
	CmdClaimSystem.TYPE: CmdClaimSystem,
	CmdOfferPeace.TYPE: CmdOfferPeace,
	CmdAnswerPeace.TYPE: CmdAnswerPeace,
	CmdSetPatrol.TYPE: CmdSetPatrol,
}


static func has(type_id: StringName) -> bool:
	return _types.has(type_id)


static func create(type_id: StringName, player_id: int, payload: Dictionary) -> Command:
	assert(_types.has(type_id), "unknown command type " + type_id)
	var cmd: Command = _types[type_id].new()
	cmd.type_id = type_id
	cmd.player_id = player_id
	cmd.payload = payload.duplicate(true)
	return cmd


## Inverse of Command.to_dict() (also accepts log entries, which have "tick" instead of exec_tick).
static func from_dict(d: Dictionary) -> Command:
	var cmd := create(StringName(d["type_id"]), int(d["player"]), _ints(d["payload"]))
	cmd.exec_tick = int(d.get("exec_tick", d.get("tick", 0)))
	cmd.seq = int(d.get("seq", 0))
	return cmd


## Payloads hold ints, Strings and arrays; numbers re-cast after a JSON trip.
static func _ints(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = _ints(v[k])
		return out
	if v is Array:
		return v.map(_ints)
	if v is String or v is StringName or v is bool:
		return v
	return int(v)
