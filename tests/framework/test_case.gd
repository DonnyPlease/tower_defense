class_name TestCase
extends RefCounted
## Base class of every test file. Methods whose names start with "test_" are
## tests; they may `await` (e.g. frames, for scene tests). Expectations record
## a failure and let the test continue, like Vitest's expect().

## The running SceneTree (for scene tests).
var tree: SceneTree
## Failures of the test that is running.
var failures: PackedStringArray = []
## Why the test was skipped ("" if it ran).
var skip_reason: String = ""


## Runs before every test.
func before_each() -> void:
	pass


## Runs after every test, even a failed one.
func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append(message)


## Marks the test as skipped: return right after (in before_each, the test doesn't run).
func skip(reason: String) -> void:
	skip_reason = reason


func _where(message: String) -> String:
	return "" if message.is_empty() else " (%s)" % message


## A value for a failure message. Objects are named, not serialised:
## var_to_str() would walk everything an object refers to (a whole game scene).
static func describe_value(value: Variant) -> String:
	if value is Object:
		var o: Object = value
		if not is_instance_valid(o):
			return "<freed object>"
		var script: Script = o.get_script()
		var name: String = script.get_global_name() if script != null and not script.get_global_name().is_empty() else o.get_class()
		return "<%s#%d>" % [name, o.get_instance_id()]
	if value is Array:
		var items: PackedStringArray = []
		var list: Array = value
		for item: Variant in list:
			items.append(describe_value(item))
		return "[%s]" % ", ".join(items)
	return var_to_str(value)


func expect_true(value: bool, message: String = "") -> void:
	if not value:
		fail("expected true" + _where(message))


func expect_false(value: bool, message: String = "") -> void:
	if value:
		fail("expected false" + _where(message))


func expect_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _equal(actual, expected):
		fail("expected %s, got %s%s" % [describe_value(expected), describe_value(actual), _where(message)])


func expect_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _equal(actual, unexpected):
		fail("expected anything but %s%s" % [describe_value(unexpected), _where(message)])


func expect_null(value: Variant, message: String = "") -> void:
	if value != null:
		fail("expected null, got %s%s" % [describe_value(value), _where(message)])


func expect_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		fail("expected a value, got null" + _where(message))


## |actual - expected| < 0.5 * 10^-digits, like Vitest's toBeCloseTo (default 2 digits).
func expect_near(actual: float, expected: float, digits: int = 2, message: String = "") -> void:
	if not absf(actual - expected) < 0.5 * pow(10.0, -digits):
		fail("expected %s to be close to %s%s" % [actual, expected, _where(message)])


func expect_gt(actual: float, bound: float, message: String = "") -> void:
	if not actual > bound:
		fail("expected %s > %s%s" % [actual, bound, _where(message)])


func expect_ge(actual: float, bound: float, message: String = "") -> void:
	if not actual >= bound:
		fail("expected %s >= %s%s" % [actual, bound, _where(message)])


func expect_lt(actual: float, bound: float, message: String = "") -> void:
	if not actual < bound:
		fail("expected %s < %s%s" % [actual, bound, _where(message)])


func expect_le(actual: float, bound: float, message: String = "") -> void:
	if not actual <= bound:
		fail("expected %s <= %s%s" % [actual, bound, _where(message)])


func expect_contains(haystack: String, needle: String, message: String = "") -> void:
	if not haystack.contains(needle):
		fail("expected %s to contain %s%s" % [var_to_str(haystack), var_to_str(needle), _where(message)])


func expect_match(text: String, pattern: String, message: String = "") -> void:
	var re := RegEx.create_from_string(pattern)
	if re.search(text) == null:
		fail("expected %s to match /%s/%s" % [var_to_str(text), pattern, _where(message)])


## Waits `count` frames (scene tests).
func frames(count: int = 1) -> void:
	for i: int in count:
		await tree.process_frame


func _equal(a: Variant, b: Variant) -> bool:
	# Numbers compare by value, whatever mix of int and float they are.
	if (a is int or a is float) and (b is int or b is float):
		var fa: float = a
		var fb: float = b
		return fa == fb
	if typeof(a) != typeof(b):
		return false
	return a == b
