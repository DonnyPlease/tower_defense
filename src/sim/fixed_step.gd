class_name FixedStep
extends RefCounted
## Fixed-timestep accumulator. The simulation always advances in whole ticks,
## so it behaves the same on 30, 60 or 144 Hz screens; the renderer gets the
## leftover fraction (alpha) to interpolate positions between ticks.

const STEP_MS: float = 1000.0 / Config.TICK_RATE
## Tolerance for floating-point drift, so a frame of exactly one step always
## runs exactly one tick (otherwise 60 Hz screens can stutter 0-2-0-2).
const EPSILON: float = 1e-6

var _accumulator: float = 0.0


## Runs `tick` as many times as `delta_ms` allows; returns the interpolation alpha.
func advance(delta_ms: float, time_scale: float, tick: Callable) -> float:
	_accumulator += minf(delta_ms, 250.0) * time_scale
	var ticks: int = 0
	while _accumulator >= STEP_MS - EPSILON and ticks < Config.MAX_TICKS_PER_FRAME * time_scale:
		tick.call()
		_accumulator -= STEP_MS
		ticks += 1
	# Fell too far behind (slow device) - drop the backlog instead of spiralling.
	if _accumulator >= STEP_MS:
		_accumulator = 0.0
	return maxf(0.0, _accumulator / STEP_MS)
