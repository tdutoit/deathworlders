class_name Construction
extends RefCounted
## One construction or upgrade in progress (Sub-spec B10). Materials are taken day by day from the site's
## stockpile, spread over the build like production (no rounding drift); a day without materials is a
## stalled day, and nothing is lost.

var kind := ""  # "building", "station" or "upgrade"
var def_id := ""  # building or station Def being built (for upgrades: the next tier)
var cost := {}  # resource ID -> milli-units in total (pace already applied)
var total_days := 1  # pace already applied
var days_done := 0
var stalled_days := 0  # consecutive days without materials (for alerts, D6)
var design := 0  # ships built from a design (M3): its ID, for the record
var components: Array[String] = []  # ... and a copy of its components at queue time


## Materials needed on day `days_done`: each resource's share of the total.
func today_need() -> Dictionary:
	var need := {}
	for res: String in IdMap.sort_keys(cost.keys()):
		var t: int = cost[res]
		var share := FixedMath.floor_div(t * (days_done + 1), total_days) - FixedMath.floor_div(t * days_done, total_days)
		if share > 0:
			need[res] = share
	return need


## Materials already consumed (for refunds on cancel).
func paid() -> Dictionary:
	var out := {}
	for res: String in cost:
		var v := FixedMath.floor_div(int(cost[res]) * days_done, total_days)
		if v > 0:
			out[res] = v
	return out


func is_done() -> bool:
	return days_done >= total_days


func to_dict() -> Dictionary:
	return {"kind": kind, "def_id": def_id, "cost": cost.duplicate(), "total_days": total_days,
		"days_done": days_done, "stalled_days": stalled_days, "design": design, "components": components.duplicate()}


static func from_dict(d: Dictionary) -> Construction:
	var c := Construction.new()
	c.kind = String(d["kind"])
	c.def_id = String(d["def_id"])
	c.cost = StateIO.int_map(d["cost"])
	c.total_days = int(d["total_days"])
	c.days_done = int(d["days_done"])
	c.stalled_days = int(d["stalled_days"])
	c.design = int(d.get("design", 0))
	c.components.assign(d.get("components", []))
	return c
