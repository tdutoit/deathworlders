class_name LegendMechanic
extends SignatureMechanic
## Legend (humans; main spec 10.4, Sub-spec E14; M4 WP9): Respect and Fear, 0..legend_max, from deeds.
## Respect: +opinion (Respect / 40), first pick of protectorate requests (300, AI in WP10), +10 opinion from all
## (600), automatic Council recognition (800). Fear: -opinion (Fear / 40), deters cautious AIs (300, WP10),
## peace 20 points cheaper (600), anyone may wage a containment war on you (800).
## State: {"respect", "fear", "kept": [treaty IDs already rewarded for 10 years]}.


static func respect(e: Empire) -> int:
	return int(e.mechanic.get("respect", 0))


static func fear(e: Empire) -> int:
	return int(e.mechanic.get("fear", 0))


func init_state(state: MatchState, e: Empire) -> void:
	var r := SignatureMechanics.rules(state)
	e.mechanic = {"respect": r.legend_start, "fear": r.legend_start, "kept": []}


func _add(state: MatchState, e: Empire, d_respect: int, d_fear: int) -> void:
	var r := SignatureMechanics.rules(state)
	e.mechanic["respect"] = clampi(respect(e) + d_respect, 0, r.legend_max)
	e.mechanic["fear"] = clampi(fear(e) + d_fear, 0, r.legend_max)


## E14: a victory while outnumbered 1.5:1; destroying an empire's capital fleet (here: half its navy in one
## battle).
func battle_resolved(state: MatchState, e: Empire, report: BattleReport) -> void:
	var r := SignatureMechanics.rules(state)
	var d := report.data
	var side := report.side_of(e.id)
	if side < 0 or not String(d["results"][side]).ends_with("victory"):
		return
	if int(d["start_cost"][1 - side]) * 1000 >= int(d["start_cost"][side]) * r.outnumbered_ratio:
		_add(state, e, r.outnumbered_respect, r.outnumbered_fear)
	var lost_by := {}
	for l: Array in d["lost"]:
		var n: Variant = d["names"].get(str(l[1]))
		if n != null and int(l[0]) != side:
			lost_by[int(n[0])] = int(lost_by.get(int(n[0]), 0)) + int(l[3])
	for enemy: int in IdMap.sort_keys(lost_by.keys()):
		if enemy < 0:
			continue
		var navy := int(lost_by[enemy]) + Treaties.power(state, enemy)
		if int(lost_by[enemy]) * 1000 >= navy * r.capital_fleet_share:
			_add(state, e, r.capital_fleet_respect, r.capital_fleet_fear)
			break


func treaty_event(state: MatchState, e: Empire, event: Dictionary) -> void:
	var r := SignatureMechanics.rules(state)
	match String(event.get("type", "")):
		"treaty_broken":
			if int(event.get("breaker", -1)) == e.id:
				_add(state, e, r.break_respect, r.break_fear)
		"protectorate_defended":
			_add(state, e, r.protect_respect, 0)
		"protectorate_failed":
			_add(state, e, r.protect_fail_respect, 0)
		"war_declared":
			if String(event.get("casus_belli", "")) == "":
				_add(state, e, r.no_cb_respect, r.no_cb_fear)


## E14: keeping a treaty 10 years.
func month_tick(state: MatchState, e: Empire) -> void:
	var r := SignatureMechanics.rules(state)
	var kept: Array = e.mechanic.get("kept", [])
	for tid: int in state.treaties.ordered():
		var t: Treaty = state.treaties.get_or(tid)
		if (t.a == e.id or t.b == e.id) and not t.id in kept \
				and state.tick - t.start_tick >= r.kept_treaty_years * Calendar.HOURS_PER_YEAR:
			kept.append(t.id)
			_add(state, e, r.kept_treaty_respect, 0)
	e.mechanic["kept"] = kept


func opinion_from(state: MatchState, e: Empire, viewer: int) -> int:
	if viewer == e.id:
		return 0
	var r := SignatureMechanics.rules(state)
	var v := FixedMath.floor_div(respect(e), r.opinion_divisor) - FixedMath.floor_div(fear(e), r.opinion_divisor)
	if respect(e) >= r.respect_all_opinion:
		v += r.respect_all_bonus
	return v


func peace_discount(state: MatchState, e: Empire) -> int:
	var r := SignatureMechanics.rules(state)
	return r.fear_peace_discount if fear(e) >= r.fear_peace else 0


func containment_target(state: MatchState, e: Empire) -> bool:
	return fear(e) >= SignatureMechanics.rules(state).fear_coalition


func auto_recognition(state: MatchState, e: Empire) -> bool:
	return respect(e) >= SignatureMechanics.rules(state).respect_recognition


func meter(_state: MatchState, e: Empire) -> Dictionary:
	return {"LEGEND_RESPECT": respect(e), "LEGEND_FEAR": fear(e)}
