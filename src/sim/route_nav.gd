class_name RouteNav
extends Nav
## Walks along a smooth route (road levels and flyers). Every enemy keeps to
## its own lane and sways a little, so a wave spreads over the road instead of
## marching in single file.

const LANE_SHIFT: float = 0.35 # how fast an enemy may change lane (px sideways per px forward)

var _route: Route
var _s: float = 0.0 # distance travelled along the route
var _i: int = 0 # current sample segment
var _offset: float # current sideways offset (px, left positive)
var _lane: float # preferred offset
var _sway: float # amplitude of the weave
var _wavelength: float
var _phase: float


func _init(route: Route, lane_seed: int, flying: bool = false, from: RouteNav = null) -> void:
	_route = route
	var spread: float = 0.9 if flying else 0.75
	_lane = (MathX.hash01(lane_seed, 1) * 2 - 1) * spread * Config.TILE
	_sway = (10.0 if flying else 4.0) + MathX.hash01(lane_seed, 2) * (12.0 if flying else 6.0)
	_wavelength = (260.0 if flying else 180.0) + MathX.hash01(lane_seed, 3) * 160
	_phase = MathX.hash01(lane_seed, 4) * PI * 2
	if from != null:
		_s = from._s
		_i = from._i
		_offset = from._offset
		heading = from.heading
	else:
		_offset = route.clamp_offset(_desired_offset(), 0)
	_place()
	if from == null:
		var b: int = mini(1, route.point_count() - 1)
		heading = atan2(route.py[b] - route.py[0], route.px[b] - route.px[0])


func _desired_offset() -> float:
	return _lane + _sway * sin((_s / _wavelength) * PI * 2 + _phase)


func _place() -> void:
	_route.at(_s, _offset, _i)
	x = _route.out_x
	y = _route.out_y


func move(step: float) -> bool:
	if step <= 0:
		return true
	var x0: float = x
	var y0: float = y
	var s0: float = _s
	var off0: float = _offset
	# Walk `ds` along the centre line; on the outside of a bend that covers
	# more ground than `ds`, so correct once to keep the real speed right.
	var ds: float = step
	for k: int in 2:
		_s = s0 + ds
		_i = _route.seek(_s, _i)
		var want: float = _desired_offset()
		var shift: float = maxf(-LANE_SHIFT * ds, minf(LANE_SHIFT * ds, want - off0))
		_offset = _route.clamp_offset_at(off0 + shift, _s, _i)
		_place()
		var moved: float = MathX.hypot(x - x0, y - y0)
		if k == 0 and moved > 1e-6:
			ds = maxf(0.5 * step, minf(2 * step, (ds * step) / moved))
	var dx: float = x - x0
	var dy: float = y - y0
	if dx * dx + dy * dy > 1e-8:
		heading = atan2(dy, dx)
	return _s < _route.length


func fall_back(dist: float) -> void:
	_s = maxf(0.0, _s - dist)
	_i = _route.seek(_s, _i)
	_offset = _route.clamp_offset_at(_offset, _s, _i)
	_place()


func remaining() -> float:
	return maxf(0.0, _route.length - _s)


func clone(lane_seed: int) -> Nav:
	return RouteNav.new(_route, lane_seed, false, self)
