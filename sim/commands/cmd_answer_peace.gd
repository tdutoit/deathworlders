class_name CmdAnswerPeace
extends Command
## core:cmd/answer_peace {"offer": ID, "accept": 0|1}, by the empire the peace offer was made to.

const TYPE := &"core:cmd/answer_peace"


func validate(state: MatchState) -> bool:
	var p: PeaceOffer = state.peace_offers.get_or(p_int("offer"))
	if p == null or p.to != player_id:
		return reject("no such offer to you")
	var w := Wars.war_of(state, p.from, p.to)
	if w == null:
		return reject("that war is over")
	if p_int("accept") == 1:
		var reason := Wars.check_terms(state, w, p.loser, p.terms)
		if reason != "":
			return reject(reason)
	return true


func apply(state: MatchState) -> void:
	var p: PeaceOffer = state.peace_offers.get_or(p_int("offer"))
	state.peace_offers.erase(p.id)
	if p_int("accept") == 1:
		Wars.make_peace(state, Wars.war_of(state, p.from, p.to), p.loser, p.terms)
