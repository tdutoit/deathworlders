class_name SignatureMechanic
extends RefCounted
## Base for a species' signature mechanic (main spec 10.1, Sub-spec C9 "signature mechanics as modules"; M4 WP2).
## One instance per mechanic, stateless: an empire's mechanic state lives in `Empire.mechanic` (ints and
## strings only; saved and part of the checksum). Hooks run inside the sim, so the determinism rules apply:
## no floats, no Godot randomness (use state.rng streams), iterate IdMaps in order. The general mod API (M9)
## grows from this; the five core mechanics are its first examples.


## Called once when the match starts (or when a save without this mechanic's state loads), to set defaults.
func init_state(_state: MatchState, _empire: Empire) -> void:
	pass


## Monthly, in empire ID order, in the month phase after the AI (Sim._month_phase).
func month_tick(_state: MatchState, _empire: Empire) -> void:
	pass


## After a battle the empire fought in has finished and its report is stored.
func battle_resolved(_state: MatchState, _empire: Empire, _report: BattleReport) -> void:
	pass


## After one of the empire's commands was applied (player or AI).
func command_applied(_state: MatchState, _empire: Empire, _cmd: Command) -> void:
	pass


## Diplomacy events (WP4 onwards): {"type": "treaty_signed" | "treaty_broken" | ..., ...}.
func treaty_event(_state: MatchState, _empire: Empire, _event: Dictionary) -> void:
	pass


## Values for the UI meter, {loc key: int} (read-only).
func meter(_state: MatchState, _empire: Empire) -> Dictionary:
	return {}
