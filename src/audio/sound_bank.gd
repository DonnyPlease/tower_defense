class_name SoundBank
extends RefCounted
## The game's sound effects and music, synthesised (there are no audio files).
## Each recipe is the one the original game played live with Web Audio.

const W := Synth.Waveform
const F := Synth.Filter

const SFX_NAMES: Array[String] = [
	"gun", "missile", "cannon", "zap", "frost", "hit", "explode", "pop", "bigExplosion",
	"build", "upgrade", "sell", "error", "click", "leak", "heal", "summon",
	"waveStart", "waveClear", "win", "lose", "rail", "mortar",
]

## Length of each effect in seconds (its last voice ends by then).
const SFX_LENGTH: Dictionary[String, float] = {
	"gun": 0.08, "missile": 0.31, "cannon": 0.31, "zap": 0.15, "frost": 0.33, "hit": 0.06, "explode": 0.38,
	"pop": 0.11, "bigExplosion": 0.93, "build": 0.13, "upgrade": 0.31, "sell": 0.24, "error": 0.17,
	"click": 0.05, "leak": 0.43, "heal": 0.23, "summon": 0.53, "waveStart": 0.78, "waveClear": 0.39,
	"win": 1.28, "lose": 0.99, "rail": 0.16, "mortar": 0.42,
}

# Music: Am - F - C - G, as MIDI notes.
const PROGRESSION_BASS: Array[int] = [45, 41, 48, 43]
const PROGRESSION_CHORDS: Array[Array] = [[57, 60, 64], [57, 60, 65], [55, 60, 64], [55, 59, 62]]
const ARP: Array[int] = [0, 1, 2, 1, 0, 2, 1, 2]
const BPM: float = 104.0
const SIXTEENTH: float = 60.0 / BPM / 4.0
const MUSIC_STEPS: int = 16 * 4 # 4 bars of sixteenths


static func midi(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)


## Renders one effect.
static func render_sfx(name: String, rate: int, noise_seed: int = 1) -> Synth:
	var s := Synth.new(rate, SFX_LENGTH[name], noise_seed)
	var t: float = 0.0
	match name:
		"gun":
			s.noise(t, 0.05, F.HIGHPASS, 2500, 2500, 0.12)
			s.tone(t, W.SQUARE, 900, 300, 0.04, 0.04)
		"missile":
			s.noise(t, 0.28, F.BANDPASS, 700, 2600, 0.14)
		"cannon":
			s.tone(t, W.SINE, 140, 45, 0.28, 0.45)
			s.noise(t, 0.18, F.LOWPASS, 900, 200, 0.25)
		"zap":
			s.tone(t, W.SAWTOOTH, 500, 1400, 0.12, 0.05)
		"frost":
			s.tone(t, W.SINE, 1900, 900, 0.3, 0.05)
			s.noise(t, 0.25, F.HIGHPASS, 6000, 6000, 0.04)
		"hit":
			s.tone(t, W.TRIANGLE, 1500, 900, 0.03, 0.035)
		"pop":
			s.tone(t, W.SQUARE, 520, 180, 0.07, 0.06)
			s.noise(t, 0.08, F.LOWPASS, 2000, 400, 0.08)
		"explode":
			s.noise(t, 0.35, F.LOWPASS, 1400, 150, 0.3)
			s.tone(t, W.SINE, 90, 35, 0.3, 0.3)
		"bigExplosion":
			s.noise(t, 0.9, F.LOWPASS, 1800, 80, 0.5)
			s.tone(t, W.SINE, 70, 25, 0.8, 0.5)
		"build":
			s.tone(t, W.SQUARE, 220, 110, 0.09, 0.08)
			s.noise(t, 0.1, F.LOWPASS, 900, 300, 0.12)
		"upgrade":
			var notes: Array[float] = [523, 659, 784, 1047]
			for i: int in notes.size():
				s.tone(t + i * 0.06, W.TRIANGLE, notes[i], notes[i], 0.1, 0.09)
		"sell":
			s.tone(t, W.SQUARE, 988, 988, 0.06, 0.06)
			s.tone(t + 0.07, W.SQUARE, 1319, 1319, 0.14, 0.06)
		"error":
			s.tone(t, W.SQUARE, 160, 140, 0.14, 0.07)
		"click":
			s.tone(t, W.TRIANGLE, 1200, 1000, 0.025, 0.05)
		"leak":
			s.tone(t, W.SAWTOOTH, 240, 100, 0.4, 0.13)
		"heal":
			s.tone(t, W.SINE, 700, 1100, 0.2, 0.04)
		"summon":
			s.tone(t, W.SAWTOOTH, 110, 70, 0.5, 0.12)
			s.noise(t, 0.4, F.LOWPASS, 500, 200, 0.1)
		"waveStart":
			s.tone(t, W.SAWTOOTH, 196, 196, 0.45, 0.07, 900)
			s.tone(t, W.SAWTOOTH, 294, 294, 0.45, 0.07, 900)
			s.tone(t + 0.25, W.SAWTOOTH, 392, 392, 0.5, 0.06, 1200)
		"waveClear":
			var notes: Array[float] = [659, 784, 988]
			for i: int in notes.size():
				s.tone(t + i * 0.09, W.TRIANGLE, notes[i], notes[i], 0.18, 0.08)
		"win":
			var notes: Array[float] = [523, 659, 784, 1047, 784, 1047]
			for i: int in notes.size():
				s.tone(t + i * 0.13, W.TRIANGLE, notes[i], notes[i], 0.6 if i == 5 else 0.16, 0.1)
		"lose":
			var notes: Array[float] = [392, 349, 311, 262]
			for i: int in notes.size():
				s.tone(t + i * 0.22, W.SAWTOOTH, notes[i], notes[i] * 0.98, 0.3, 0.07, 1400)
		"rail":
			s.noise(t, 0.05, F.HIGHPASS, 4000, 4000, 0.16)
			s.tone(t, W.SAWTOOTH, 2400, 500, 0.14, 0.06, 3000)
		"mortar":
			s.tone(t, W.SINE, 95, 38, 0.38, 0.5)
			s.noise(t, 0.3, F.LOWPASS, 700, 120, 0.22)
		_:
			push_error("Unknown sound '%s'" % name)
	return s


## Length of the music loop in seconds.
static func music_length() -> float:
	return MUSIC_STEPS * SIXTEENTH


## Empty looping buffers for the two music layers: calm (bass, arpeggio and
## pads) and drums (kick and hi-hats, which play during waves).
static func music_buffers(rate: int) -> Array[Synth]:
	return [Synth.new(rate, music_length(), 7, true), Synth.new(rate, music_length(), 8, true)]


## Renders sixteenth `step` (0..MUSIC_STEPS-1) of both music layers.
static func render_music_step(calm: Synth, drums: Synth, step: int) -> void:
	var t: float = step * SIXTEENTH
	@warning_ignore("integer_division")
	var bar: int = step / 16
	var s: int = step % 16
	var chord: Array = PROGRESSION_CHORDS[bar]
	if s % 4 == 0:
		calm.note(t, midi(PROGRESSION_BASS[bar]), SIXTEENTH * 3.5, W.TRIANGLE, 0.22, 600)
	if s % 2 == 0:
		@warning_ignore("integer_division")
		var arp_note: int = chord[ARP[(s / 2) % ARP.size()]]
		calm.note(t, midi(arp_note + 12), SIXTEENTH * 1.8, W.SQUARE, 0.035, 1800)
	if s == 0:
		for n: int in chord:
			calm.note(t, midi(n), SIXTEENTH * 15, W.SINE, 0.04, 1200)
	if s % 4 == 0:
		drums.kick(t)
	if s % 2 == 1:
		drums.noise(t, 0.04, F.HIGHPASS, 7000, 7000, 0.05)
