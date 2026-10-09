class_name Route
extends RefCounted
## A smooth path through a list of corner points, sampled every few pixels.
## For every sample it also knows how far an enemy may walk to either side of
## the centre line and still stay on the road, so enemies can use lanes.
##
## Coordinates are kept in 64-bit float arrays (Vector2 is only 32-bit).

const SAMPLE: float = 4.0 # pixels between samples of a smoothed route
const INNER_BEND: float = 0.6 # fraction of a bend's radius usable on its inside
const WIDTH_SLOPE: float = 0.2 # how fast the usable width may change along the route (px per px)
const MARGIN: float = 14.0 # the centre line keeps this far from the verge
const SMOOTH_PASSES: int = 200


## A polyline as two coordinate arrays.
class Polyline:
	var x: PackedFloat64Array
	var y: PackedFloat64Array

	func _init(p_x: PackedFloat64Array = PackedFloat64Array(), p_y: PackedFloat64Array = PackedFloat64Array()) -> void:
		x = p_x
		y = p_y

	func size() -> int:
		return x.size()

	func add(px: float, py: float) -> void:
		x.append(px)
		y.append(py)


var px: PackedFloat64Array
var py: PackedFloat64Array
## Unit normals pointing to the left of the walking direction.
var nx: PackedFloat64Array
var ny: PackedFloat64Array
## Path length from the start to each sample.
var cum: PackedFloat64Array
## Usable offset to the left (positive) and right (negative normal) of each sample.
var left: PackedFloat64Array
var right: PackedFloat64Array
var length: float

## Result of the last at() call (avoids allocating a point per call).
var out_x: float = 0.0
var out_y: float = 0.0


## `corners` is the polyline to smooth (first and last points are kept).
## `free(px, py, nx, ny)` is how far one may go from (px, py) along (nx, ny).
## With `clearance(x, y)` (distance to the nearest spot enemies can't walk
## on) the path is relaxed into curves as wide as the road allows; without it,
## the corners are just rounded.
func _init(corners: Polyline, free: Callable, clearance: Callable = Callable()) -> void:
	var pts: Polyline = round_path(corners, clearance) if clearance.is_valid() else resample(chaikin(corners, 2), SAMPLE)
	px = pts.x
	py = pts.y
	var n: int = px.size()
	nx.resize(n)
	ny.resize(n)
	cum.resize(n)
	cum[0] = 0.0
	for i: int in n:
		var a: int = maxi(0, i - 1)
		var b: int = mini(n - 1, i + 1)
		var seg_len: float = MathX.hypot(px[b] - px[a], py[b] - py[a])
		if seg_len == 0.0:
			seg_len = 1.0
		nx[i] = (py[b] - py[a]) / seg_len
		ny[i] = -(px[b] - px[a]) / seg_len
		if i > 0:
			cum[i] = cum[i - 1] + MathX.hypot(px[i] - px[i - 1], py[i] - py[i - 1])
	length = cum[n - 1]
	left.resize(n)
	right.resize(n)
	for i: int in n:
		left[i] = free.call(px[i], py[i], nx[i], ny[i])
	for i: int in n:
		right[i] = free.call(px[i], py[i], -nx[i], -ny[i])
	# On the inside of a bend, stay closer to the middle than the bend's
	# radius, or the lane would loop backwards.
	for i: int in range(1, n - 1):
		var ax: float = px[i - 1]
		var ay: float = py[i - 1]
		var bx: float = px[i]
		var by: float = py[i]
		var cx: float = px[i + 1]
		var cy: float = py[i + 1]
		var cross: float = (bx - ax) * (cy - by) - (by - ay) * (cx - bx)
		if absf(cross) < 1e-9:
			continue
		var radius: float = (MathX.hypot(bx - ax, by - ay) * MathX.hypot(cx - bx, cy - by) * MathX.hypot(cx - ax, cy - ay)) \
			/ (2 * absf(cross))
		var limit: float = INNER_BEND * radius
		if nx[i] * (ax + cx - 2 * bx) + ny[i] * (ay + cy - 2 * by) > 0:
			left[i] = minf(left[i], limit)
		else:
			right[i] = minf(right[i], limit)
	left = _limit_slope(left, cum)
	right = _limit_slope(right, cum)


func point_count() -> int:
	return px.size()


## Index of the sample segment containing distance `s`, starting the search at `hint`.
func seek(s: float, hint: int = 0) -> int:
	var last: int = px.size() - 2
	var i: int = maxi(0, mini(hint, last))
	while i < last and cum[i + 1] <= s:
		i += 1
	while i > 0 and cum[i] > s:
		i -= 1
	return i


## Point at distance `s` along the route, shifted `offset` pixels to the left,
## written to out_x / out_y. `i` is the sample segment (see seek()).
func at(s: float, offset: float, i: int) -> void:
	var j: int = i + 1 if i + 1 < px.size() else i
	var seg: float = (cum[j] - cum[i]) if j != i else 0.0
	if seg == 0.0:
		seg = 1.0
	var t: float = clampf((s - cum[i]) / seg, 0.0, 1.0)
	out_x = px[i] + (px[j] - px[i]) * t + (nx[i] + (nx[j] - nx[i]) * t) * offset
	out_y = py[i] + (py[j] - py[i]) * t + (ny[i] + (ny[j] - ny[i]) * t) * offset


## Allowed offset range [-right, left] at sample `i`.
func clamp_offset(offset: float, i: int) -> float:
	return maxf(-right[i], minf(left[i], offset))


## Allowed offset range at distance `s` (in sample segment `i`), blended
## between the samples so a lane at the edge of the road changes smoothly
## (clamping to one sample's width at a time made enemies jitter sideways).
func clamp_offset_at(offset: float, s: float, i: int) -> float:
	var j: int = i + 1 if i + 1 < px.size() else i
	var seg: float = cum[j] - cum[i]
	var t: float = clampf((s - cum[i]) / seg, 0.0, 1.0) if seg > 0.0 else 0.0
	var l: float = left[i] + (left[j] - left[i]) * t
	var r: float = right[i] + (right[j] - right[i]) * t
	return maxf(-r, minf(l, offset))


## Turns a tile-by-tile path (along the middle of the road) into a natural
## curve: relaxes the zig-zags into diagonals and the corners into arcs as
## wide as the road allows. `clearance(x, y)` is the distance from (x, y) to
## the nearest spot enemies can't walk on.
static func round_path(pts: Polyline, clearance: Callable) -> Polyline:
	var p: Polyline = resample(pts, SAMPLE)
	var xs: PackedFloat64Array = p.x
	var ys: PackedFloat64Array = p.y
	var n: int = xs.size()
	# Clearance of every point, updated whenever the point moves.
	var here := PackedFloat64Array()
	here.resize(n)
	for i: int in range(1, n - 1):
		here[i] = clearance.call(xs[i], ys[i])
	for _pass: int in SMOOTH_PASSES:
		for i: int in range(1, n - 1):
			var qx: float = (xs[i] + (xs[i - 1] + xs[i + 1]) / 2) / 2
			var qy: float = (ys[i] + (ys[i - 1] + ys[i + 1]) / 2) / 2
			var there: float = clearance.call(qx, qy)
			if there >= minf(MARGIN, here[i]):
				xs[i] = qx
				ys[i] = qy
				here[i] = there
	return resample(Polyline.new(xs, ys), SAMPLE)


## Chaikin corner cutting: rounds every corner, keeps the end points.
static func chaikin(pts: Polyline, iterations: int) -> Polyline:
	var out: Polyline = pts
	for _k: int in iterations:
		var next := Polyline.new()
		next.add(out.x[0], out.y[0])
		for i: int in out.size() - 1:
			var ax: float = out.x[i]
			var ay: float = out.y[i]
			var bx: float = out.x[i + 1]
			var by: float = out.y[i + 1]
			next.add(0.75 * ax + 0.25 * bx, 0.75 * ay + 0.25 * by)
			next.add(0.25 * ax + 0.75 * bx, 0.25 * ay + 0.75 * by)
		next.add(out.x[out.size() - 1], out.y[out.size() - 1])
		out = next
	return out


## Points spaced `step` pixels apart along the polyline.
static func resample(pts: Polyline, step: float) -> Polyline:
	var out := Polyline.new()
	out.add(pts.x[0], pts.y[0])
	var carry: float = 0.0 # distance walked since the last emitted point
	for i: int in pts.size() - 1:
		var ax: float = pts.x[i]
		var ay: float = pts.y[i]
		var bx: float = pts.x[i + 1]
		var by: float = pts.y[i + 1]
		var seg_len: float = MathX.hypot(bx - ax, by - ay)
		var t: float = step - carry
		while t <= seg_len:
			out.add(ax + ((bx - ax) * t) / seg_len, ay + ((by - ay) * t) / seg_len)
			t += step
		carry = seg_len - (t - step)
	var last: int = pts.size() - 1
	var tail: int = out.size() - 1
	if MathX.hypot(pts.x[last] - out.x[tail], pts.y[last] - out.y[tail]) > 1e-6:
		out.add(pts.x[last], pts.y[last])
	return out


## Makes widths change gradually, so a lane narrows before the road does.
static func _limit_slope(w: PackedFloat64Array, cum_len: PackedFloat64Array) -> PackedFloat64Array:
	for i: int in range(1, w.size()):
		w[i] = minf(w[i], w[i - 1] + WIDTH_SLOPE * (cum_len[i] - cum_len[i - 1]))
	for i: int in range(w.size() - 2, -1, -1):
		w[i] = minf(w[i], w[i + 1] + WIDTH_SLOPE * (cum_len[i + 1] - cum_len[i]))
	return w
