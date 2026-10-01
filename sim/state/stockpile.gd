class_name Stockpile
extends RefCounted
## A local stockpile (Sub-spec B5), in milli-units (1 unit = 1000, B0). Caps are computed by the economy
## (they depend on modifiers), so adds take the cap as an argument; anything above it is lost.

const MILLI := 1000

var amounts := {}  # resource ID -> milli-units (never negative; zero entries are dropped)


func milli(res: String) -> int:
	return amounts.get(res, 0)


func units(res: String) -> int:
	@warning_ignore("integer_division")
	return milli(res) / MILLI


## Adds up to cap_milli (0 = uncapped). Returns the overflow that was lost.
func add(res: String, amount: int, cap_milli: int = 0) -> int:
	if amount <= 0:
		return 0
	var total := milli(res) + amount
	var lost := 0
	if cap_milli > 0 and total > cap_milli:
		lost = total - maxi(cap_milli, milli(res))
		total -= lost
	_store(res, total)
	return lost


## Removes up to amount; returns what was actually taken.
func take(res: String, amount: int) -> int:
	var taken := mini(amount, milli(res))
	if taken > 0:
		_store(res, milli(res) - taken)
	return taken


func _store(res: String, value: int) -> void:
	if value <= 0:
		amounts.erase(res)
	else:
		amounts[res] = value


func to_dict() -> Dictionary:
	return amounts.duplicate()


static func from_dict(d: Dictionary) -> Stockpile:
	var s := Stockpile.new()
	s.amounts = StateIO.int_map(d)
	return s
