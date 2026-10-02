class_name CmdProposeDeal
extends Command
## core:cmd/propose_deal {"to": empire ID, "items": [deal items, see Deal], "treaty": treaty Def ID or ""}
## (E5, E6). A deal alone, a gift, or a treaty sweetened by a deal. An AI answers at once (E5 with the deal
## balance; gifts are always accepted); a player gets a proposal.

const TYPE := &"core:cmd/propose_deal"


func validate(state: MatchState) -> bool:
	var to := p_int("to")
	var treaty := str(payload.get("treaty", ""))
	var items: Array = payload.get("items", []) if payload.get("items", []) is Array else []
	if state.empire(to) == null or to == player_id or not Relations.has_contact(state, player_id, to):
		return reject("no contact with empire %d" % to)
	if state.wars.has(Battles.war_key(player_id, to)):
		return reject("at war: make peace first")
	if treaty != "":
		var reason := Treaties.check_propose(state, player_id, to, treaty)
		if reason != "":
			return reject(reason)
	var with_trade := treaty != "" and Treaties.def_of(state, treaty).has("trade")
	var deal_reason := Deals.check(state, player_id, to, items, with_trade)
	return reject(deal_reason) if deal_reason != "" else true


func apply(state: MatchState) -> void:
	var to := p_int("to")
	var treaty := str(payload.get("treaty", ""))
	var items: Array = (payload["items"] as Array).duplicate(true)
	if Autopilot.is_ai(state, to):
		if Treaties.accepts(state, player_id, to, treaty, items):
			if treaty != "":
				Treaties.sign(state, player_id, to, treaty)
			Deals.execute(state, player_id, to, items)
		elif treaty != "":
			Treaties.refuse(state, player_id, to, treaty)
		return
	var p := Proposal.new()
	p.id = state.alloc_id()
	p.def_id = treaty
	p.from = player_id
	p.to = to
	p.items = items
	p.tick = state.tick
	p.expires_tick = state.tick + Treaties.rules(state).proposal_days * Calendar.HOURS_PER_DAY
	state.proposals.put(p.id, p)
