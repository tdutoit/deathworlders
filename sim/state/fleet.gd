class_name Fleet
extends RefCounted
## A fleet of warships (main spec 7.1, 7.6). Its ships share one position and route; `task_forces` holds the
## hierarchy as ship IDs: task forces -> squadrons -> ships (auto-grouped by class, Fleets.regroup).
## Doctrine is the player's battle control; formation and stance are stored for later rules (M3: no effect).

const RANGES: Array[String] = ["standoff", "line", "close", "boarding"]
const TARGETS: Array[String] = ["largest", "weakest", "carriers", "escorts", "missiles"]
const RETREATS: Array[int] = [0, 250, 500, 750]  # losses that trigger retreat (permille); 0 = never
const FORMATIONS: Array[String] = ["screen_forward", "wedge", "sphere", "dispersed"]
const STANCES: Array[String] = ["aggressive", "balanced", "defensive", "delaying"]

var id: int
var owner: int
var name := ""  # "" = the UI's default name
var reserve := false  # the fleet new ships join (one per system, until it moves)
var task_forces: Array = []  # [[[ship ID, ...] per squadron] per task force]
var range_pref := "line"
var target_priority := "largest"
var retreat_at := 500
var formation := "screen_forward"
var stance := "balanced"
var defeated_tick := 0  # last lost battle (A10: recent defeat, -100 starting morale)
var mission := ""  # "", "escort" (a hub's freighters) or "patrol" (a list of systems)
var escort_hub: int = StateIO.NONE
var patrol: Array[int] = []  # systems, visited in order
var patrol_index := 0
var patrol_wait := 0  # hours spent at the current patrol system


## Every ship in hierarchy order.
func ships() -> Array[int]:
	var out: Array[int] = []
	for tf: Array in task_forces:
		for sq: Array in tf:
			for sid: int in sq:
				out.append(sid)
	return out


func size() -> int:
	return ships().size()


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "name": name, "reserve": reserve, "task_forces": task_forces.duplicate(true),
		"range_pref": range_pref, "target_priority": target_priority, "retreat_at": retreat_at,
		"formation": formation, "stance": stance, "defeated_tick": defeated_tick, "mission": mission,
		"escort_hub": escort_hub, "patrol": patrol.duplicate(), "patrol_index": patrol_index, "patrol_wait": patrol_wait}


static func from_dict(d: Dictionary) -> Fleet:
	var f := Fleet.new()
	f.id = int(d["id"])
	f.owner = int(d["owner"])
	f.name = String(d.get("name", ""))
	f.reserve = d.get("reserve", false) == true
	for tf: Array in d.get("task_forces", []):
		var squads := []
		for sq: Array in tf:
			squads.append(StateIO.ints(sq))
		f.task_forces.append(squads)
	f.range_pref = String(d.get("range_pref", "line"))
	f.target_priority = String(d.get("target_priority", "largest"))
	f.retreat_at = int(d.get("retreat_at", 500))
	f.formation = String(d.get("formation", "screen_forward"))
	f.stance = String(d.get("stance", "balanced"))
	f.defeated_tick = int(d.get("defeated_tick", 0))
	f.mission = String(d.get("mission", ""))
	f.escort_hub = int(d.get("escort_hub", StateIO.NONE))
	f.patrol = StateIO.ints(d.get("patrol", []))
	f.patrol_index = int(d.get("patrol_index", 0))
	f.patrol_wait = int(d.get("patrol_wait", 0))
	return f
