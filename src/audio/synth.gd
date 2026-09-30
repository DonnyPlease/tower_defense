class_name Synth
extends RefCounted
## Offline renderer for the sounds of the game: oscillators with exponential
## pitch sweeps, noise bursts, biquad filters and exponential envelopes, as
## specified by the Web Audio API (the original game synthesised its sound
## live with it). Voices are mixed into a mono buffer that becomes an
## AudioStreamWAV. With `loop`, sound running past the end wraps around to the
## start, so a looped buffer has no gap.

enum Waveform { SINE, SQUARE, SAWTOOTH, TRIANGLE }
enum Filter { NONE, LOWPASS, HIGHPASS, BANDPASS }

## Envelopes ramp exponentially from/to this (Web Audio can't ramp to 0).
const SILENT: float = 0.0001
## Filter coefficients are recalculated every this many samples during sweeps.
const FILTER_STEP: int = 16

var rate: int
var buffer: PackedFloat32Array
var loop: bool
var _noise: PackedFloat32Array
var _rng := RandomNumberGenerator.new()


## `seconds` long at `rate` Hz. `noise_seed` makes the noise (and the
## result) reproducible.
func _init(p_rate: int, seconds: float, noise_seed: int = 1, p_loop: bool = false) -> void:
	rate = p_rate
	loop = p_loop
	buffer.resize(maxi(1, ceili(seconds * rate)))
	_rng.seed = noise_seed
	# One second of white noise, like the original's noise buffer.
	_noise.resize(rate)
	for i: int in rate:
		_noise[i] = _rng.randf() * 2 - 1


## Number of samples a sound of `seconds` needs.
func samples(seconds: float) -> int:
	return ceili(seconds * rate)


## An oscillator sweeping exponentially from `from` to `to` Hz over `dur`
## seconds, with a 5 ms attack and an exponential decay over `dur`; optionally
## through a lowpass filter. Starts at `t` seconds.
func tone(t: float, wave: Waveform, from: float, to: float, dur: float, vol: float, lowpass: float = 0.0) -> void:
	var biquad := Biquad.new()
	if lowpass > 0:
		biquad.set_filter(Filter.LOWPASS, lowpass, rate)
	var target: float = maxf(20.0, to)
	var n: int = samples(dur + 0.02)
	var start: int = roundi(t * rate)
	var phase: float = 0.0
	for i: int in n:
		var time: float = float(i) / rate
		var f: float = from if to == from else from * pow(target / from, minf(1.0, time / dur))
		var s: float = oscillator(wave, phase, f / rate)
		phase = fposmod(phase + f / rate, 1.0)
		if lowpass > 0:
			s = biquad.process(s)
		_mix(start + i, s * _attack_decay(time, 0.005, dur, vol))


## A burst of filtered noise: the filter's frequency sweeps exponentially
## from `from` to `to` Hz over `dur`, the volume decays exponentially from
## `vol`. `offset` is where in the noise buffer to start (seconds, as random
## as the original's).
func noise(t: float, dur: float, filter: Filter, from: float, to: float, vol: float, offset: float = -1.0) -> void:
	if offset < 0:
		offset = _rng.randf() * 0.5
	var biquad := Biquad.new()
	var n: int = samples(dur + 0.02)
	var start: int = roundi(t * rate)
	var first: int = roundi(offset * rate)
	for i: int in n:
		var time: float = float(i) / rate
		if i % FILTER_STEP == 0:
			var f: float = from if to == from else from * pow(to / from, minf(1.0, time / dur))
			biquad.set_filter(filter, f, rate)
		# The noise buffer is one second long and does not loop.
		var src: int = first + i
		var s: float = _noise[src] if src < _noise.size() else 0.0
		var gain: float = vol * pow(SILENT / vol, minf(1.0, time / dur)) if time < dur else SILENT
		_mix(start + i, biquad.process(s) * gain)


## A music note: fixed pitch through a lowpass, 10 ms attack, decay over `dur`.
func note(t: float, freq: float, dur: float, wave: Waveform, vol: float, cutoff: float) -> void:
	var biquad := Biquad.new()
	biquad.set_filter(Filter.LOWPASS, cutoff, rate)
	var n: int = samples(dur + 0.05)
	var start: int = roundi(t * rate)
	var phase: float = 0.0
	var step: float = freq / rate
	for i: int in n:
		var time: float = float(i) / rate
		var s: float = biquad.process(oscillator(wave, phase, step))
		phase = fposmod(phase + step, 1.0)
		_mix(start + i, s * _attack_decay(time, 0.01, dur, vol))


## A kick drum: a sine sweeping from 130 to 40 Hz in 0.12 s, decaying from 0.35 over 0.15 s.
func kick(t: float) -> void:
	var n: int = samples(0.2)
	var start: int = roundi(t * rate)
	var phase: float = 0.0
	for i: int in n:
		var time: float = float(i) / rate
		var f: float = 130.0 * pow(40.0 / 130.0, minf(1.0, time / 0.12))
		var gain: float = 0.35 * pow(SILENT / 0.35, minf(1.0, time / 0.15)) if time < 0.15 else SILENT
		_mix(start + i, sin(TAU * phase) * gain)
		phase = fposmod(phase + f / rate, 1.0)


## Exponential attack from SILENT to `vol` over `attack` seconds, then an
## exponential decay back to SILENT at `dur` seconds.
static func _attack_decay(time: float, attack: float, dur: float, vol: float) -> float:
	if time < attack:
		return SILENT * pow(vol / SILENT, time / attack)
	if time < dur:
		return vol * pow(SILENT / vol, (time - attack) / (dur - attack))
	return SILENT


## One sample of a waveform at `phase` (0..1). Like Web Audio's, every wave
## starts at 0 (square at +1) and rises; square and sawtooth are band-limited
## (PolyBLEP), so high notes don't alias.
static func oscillator(wave: Waveform, phase: float, step: float) -> float:
	match wave:
		Waveform.SINE:
			return sin(TAU * phase)
		Waveform.SQUARE:
			var sq: float = 1.0 if phase < 0.5 else -1.0
			return sq + _poly_blep(phase, step) - _poly_blep(fposmod(phase + 0.5, 1.0), step)
		Waveform.SAWTOOTH:
			# Rises from 0 to 1, drops to -1 half way through the period.
			var p: float = fposmod(phase + 0.5, 1.0)
			return 2.0 * p - 1.0 - _poly_blep(p, step)
		Waveform.TRIANGLE:
			return 4.0 * absf(fposmod(phase - 0.25, 1.0) - 0.5) - 1.0
	return 0.0


static func _poly_blep(t: float, dt: float) -> float:
	if dt <= 0:
		return 0.0
	if t < dt:
		var x: float = t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var x: float = (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


func _mix(index: int, value: float) -> void:
	if loop:
		index = posmod(index, buffer.size())
	elif index < 0 or index >= buffer.size():
		return
	buffer[index] += value


## The buffer as a 16-bit mono stream (looping over its whole length with `loop`).
func to_stream() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)
	for i: int in buffer.size():
		data.encode_s16(i * 2, clampi(roundi(buffer[i] * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buffer.size()
	return stream


## Peak absolute sample value (tests).
func peak() -> float:
	var p: float = 0.0
	for s: float in buffer:
		p = maxf(p, absf(s))
	return p


## A biquad filter with the Web Audio API's coefficient formulas (Q = 1, the
## default; for lowpass and highpass Q is in dB).
class Biquad:
	var _b0: float = 1.0
	var _b1: float = 0.0
	var _b2: float = 0.0
	var _a1: float = 0.0
	var _a2: float = 0.0
	var _x1: float = 0.0
	var _x2: float = 0.0
	var _y1: float = 0.0
	var _y2: float = 0.0

	func set_filter(type: Filter, frequency: float, sample_rate: int) -> void:
		var f: float = clampf(frequency, 1.0, sample_rate * 0.5 - 1.0)
		var w0: float = TAU * f / sample_rate
		var cos_w: float = cos(w0)
		var a0: float
		match type:
			Filter.LOWPASS, Filter.HIGHPASS:
				var alpha: float = sin(w0) / (2.0 * pow(10.0, 1.0 / 20.0))
				a0 = 1.0 + alpha
				_a1 = -2.0 * cos_w / a0
				_a2 = (1.0 - alpha) / a0
				if type == Filter.LOWPASS:
					_b0 = (1.0 - cos_w) / 2.0 / a0
					_b1 = (1.0 - cos_w) / a0
					_b2 = _b0
				else:
					_b0 = (1.0 + cos_w) / 2.0 / a0
					_b1 = -(1.0 + cos_w) / a0
					_b2 = _b0
			Filter.BANDPASS:
				var alpha_bp: float = sin(w0) / 2.0
				a0 = 1.0 + alpha_bp
				_b0 = alpha_bp / a0
				_b1 = 0.0
				_b2 = -alpha_bp / a0
				_a1 = -2.0 * cos_w / a0
				_a2 = (1.0 - alpha_bp) / a0
			_:
				_b0 = 1.0
				_b1 = 0.0
				_b2 = 0.0
				_a1 = 0.0
				_a2 = 0.0

	func process(x: float) -> float:
		var y: float = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2
		_x2 = _x1
		_x1 = x
		_y2 = _y1
		_y1 = y
		return y
