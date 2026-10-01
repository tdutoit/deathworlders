class_name Calendar
extends RefCounted
## Game calendar (M1 WP5): 1 tick = 1 hour, 30-day months, 360-day years, starting 2200-01-01.

const HOURS_PER_DAY := 24
const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12
const HOURS_PER_MONTH := HOURS_PER_DAY * DAYS_PER_MONTH
const HOURS_PER_YEAR := HOURS_PER_MONTH * MONTHS_PER_YEAR
const START_YEAR := 2200


## {year, month (1-12), day (1-30), hour (0-23)} for a tick count.
static func date(tick: int) -> Dictionary:
	@warning_ignore("integer_division")
	var years := tick / HOURS_PER_YEAR
	@warning_ignore("integer_division")
	var months := (tick % HOURS_PER_YEAR) / HOURS_PER_MONTH
	@warning_ignore("integer_division")
	var days := (tick % HOURS_PER_MONTH) / HOURS_PER_DAY
	return {"year": START_YEAR + years, "month": months + 1, "day": days + 1, "hour": tick % HOURS_PER_DAY}


## "2200-01-01 00:00" (not localised; UI formats its own).
static func format(tick: int) -> String:
	var d := date(tick)
	return "%04d-%02d-%02d %02d:00" % [d["year"], d["month"], d["day"], d["hour"]]


static func is_day_start(tick: int) -> bool:
	return tick % HOURS_PER_DAY == 0


static func is_month_start(tick: int) -> bool:
	return tick % HOURS_PER_MONTH == 0
