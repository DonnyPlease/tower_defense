class_name JsonRead
extends RefCounted
## Typed reads from parsed JSON (which has only floats for numbers).


static func is_number(v: Variant) -> bool:
	return v is int or v is float


## A JSON number as an int (fractions are dropped), or `fallback` if `v` is not a number.
static func int_or(v: Variant, fallback: int = 0) -> int:
	if v is int:
		return v
	if v is float:
		var f: float = v
		return int(f)
	return fallback
