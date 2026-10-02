class_name CmdOfferPeace
extends Command
## core:cmd/offer_peace {"empire": ID, "loser": the side giving the terms, "terms": [{"type", "ref", "amount"}]}
## (E7). An AI loser accepts when the terms cost no more than the demander's war score plus half the exhaustion
## gap; an AI winner accepts terms worth at least that same limit. A player gets an offer to answer.

const TYPE := &"core:cmd/offer_peace"


func validate(state: MatchState) -> bool:
	var w := Wars.war_of(state, player_id, p_int("empire"))
	if w == null:
		return reject("not at war with empire %d" % p_int("empire"))
	var loser := p_int("loser")
	if loser != player_id and loser != p_int("empire"):
		return reject("the loser is one of the two")
	var terms: Array = payload.get("terms", []) if payload.get("terms", []) is Array else []
	var reason := Wars.check_terms(state, w, loser, terms)
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	var other := p_int("empire")
	var w := Wars.war_of(state, player_id, other)
	var loser := p_int("loser")
	var terms: Array = (payload.get("terms", []) as Array).duplicate(true)
	if Autopilot.is_ai(state, other):
		if Wars.accepts(state, w, loser, terms) if loser == other else Wars.accepts_offer(state, w, loser, terms):
			Wars.make_peace(state, w, loser, terms)
		return
	var p := PeaceOffer.new()
	p.id = state.alloc_id()
	p.from = player_id
	p.to = other
	p.loser = loser
	p.terms = terms
	p.tick = state.tick
	p.expires_tick = state.tick + Wars.rules(state).peace_days * Calendar.HOURS_PER_DAY
	state.peace_offers.put(p.id, p)
