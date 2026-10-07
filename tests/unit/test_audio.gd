extends TestCase
## The synthesiser, the sound recipes and the audio engine.

const RATE: int = 8000

var engine: AudioEngine


func after_each() -> void:
	if engine != null:
		engine.queue_free()


func make_engine() -> AudioEngine:
	engine = AudioEngine.new()
	tree.root.add_child(engine)
	return engine


func test_every_sound_effect_renders_audible_unclipped_samples() -> void:
	for name: String in SoundBank.SFX_NAMES:
		var s: Synth = SoundBank.render_sfx(name, RATE)
		expect_gt(s.peak(), 0.01, name + " is audible")
		expect_lt(s.peak(), 1.0, name + " does not clip")
		# Its voices end before the buffer does.
		var tail: float = 0.0
		for i: int in range(s.buffer.size() - roundi(0.005 * RATE), s.buffer.size()):
			tail = maxf(tail, absf(s.buffer[i]))
		expect_lt(tail, 0.01, name + " fits in its length")


func test_rendering_is_reproducible() -> void:
	expect_eq(SoundBank.render_sfx("explode", RATE).buffer, SoundBank.render_sfx("explode", RATE).buffer)


func test_tones_sweep_their_pitch_exponentially() -> void:
	# A 1 s sine from 100 to 400 Hz: zero crossings get closer together.
	var s := Synth.new(RATE, 1.1)
	s.tone(0, Synth.Waveform.SINE, 100, 400, 1.0, 0.5)
	var early: int = crossings(s.buffer, 0, floori(RATE * 0.1))
	var late: int = crossings(s.buffer, floori(RATE * 0.8), floori(RATE * 0.9))
	expect_gt(late, early * 2)


func crossings(b: PackedFloat32Array, from: int, to: int) -> int:
	var n: int = 0
	for i: int in range(from + 1, to):
		if (b[i - 1] < 0) != (b[i] < 0):
			n += 1
	return n


func test_waveforms_start_like_web_audio() -> void:
	expect_near(Synth.oscillator(Synth.Waveform.SINE, 0, 0.01), 0)
	expect_near(Synth.oscillator(Synth.Waveform.TRIANGLE, 0, 0.01), 0)
	expect_near(Synth.oscillator(Synth.Waveform.TRIANGLE, 0.25, 0.01), 1)
	expect_near(Synth.oscillator(Synth.Waveform.SAWTOOTH, 0.25, 0.01), 0.5)
	expect_near(Synth.oscillator(Synth.Waveform.SQUARE, 0.25, 0.01), 1)
	expect_near(Synth.oscillator(Synth.Waveform.SQUARE, 0.75, 0.01), -1)


func test_filters_pass_and_block_what_they_should() -> void:
	# 3 kHz tone: a 500 Hz lowpass removes most of it, a 500 Hz highpass keeps it.
	var low := Synth.Biquad.new()
	low.set_filter(Synth.Filter.LOWPASS, 500, RATE)
	var high := Synth.Biquad.new()
	high.set_filter(Synth.Filter.HIGHPASS, 500, RATE)
	var low_peak: float = 0.0
	var high_peak: float = 0.0
	for i: int in RATE:
		var x: float = sin(TAU * 3000.0 * i / RATE)
		var l: float = low.process(x)
		var h: float = high.process(x)
		if i > RATE * 0.5:
			low_peak = maxf(low_peak, absf(l))
			high_peak = maxf(high_peak, absf(h))
	expect_lt(low_peak, 0.1)
	expect_gt(high_peak, 0.9)


func test_the_music_layers_loop_seamlessly_and_have_the_same_length() -> void:
	var layers: Array[Synth] = SoundBank.music_buffers(RATE)
	for step: int in SoundBank.MUSIC_STEPS:
		SoundBank.render_music_step(layers[0], layers[1], step)
	expect_eq(layers[0].buffer.size(), layers[1].buffer.size())
	expect_near(layers[0].buffer.size() / float(RATE), SoundBank.music_length(), 3)
	expect_gt(layers[0].peak(), 0.05, "melody")
	expect_gt(layers[1].peak(), 0.05, "drums")
	# Long pads ring past the end of the loop and wrap around to its start.
	expect_gt(absf(layers[0].buffer[10]), 0.0)
	var stream: AudioStreamWAV = layers[0].to_stream()
	expect_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	expect_eq(stream.loop_end, layers[0].buffer.size())


func test_is_silent_until_the_sounds_are_ready() -> void:
	var a: AudioEngine = make_engine()
	a.play("gun")
	expect_eq(a.plays, 0)
	expect_false(a.is_ready())


func test_plays_every_sound_effect() -> void:
	var a: AudioEngine = make_engine()
	a.set_music(false)
	a.render_now(RATE, RATE)
	await frames(1) # sounds are installed on the main thread
	expect_true(a.is_ready())
	a.now_override_msec = 0
	for name: String in SoundBank.SFX_NAMES:
		var before: int = a.plays
		a.now_override_msec += 1000
		a.play(name)
		expect_eq(a.plays, before + 1, name)


func test_throttles_rapid_repeats_of_the_same_sound() -> void:
	var a: AudioEngine = make_engine()
	a.set_music(false)
	a.render_now(RATE, RATE)
	await frames(1)
	a.now_override_msec = 1000
	a.play("gun")
	expect_eq(a.plays, 1)
	a.play("gun") # same instant: dropped
	expect_eq(a.plays, 1)
	a.now_override_msec += 100
	a.play("gun")
	expect_eq(a.plays, 2)


func test_plays_nothing_when_effects_are_muted() -> void:
	var a: AudioEngine = make_engine()
	a.set_music(false)
	a.render_now(RATE, RATE)
	await frames(1)
	a.set_sfx(false)
	expect_false(a.sfx_enabled)
	a.play("explode")
	expect_eq(a.plays, 0)
	a.set_sfx(true)


func test_renders_everything_on_a_worker_thread() -> void:
	var a: AudioEngine = make_engine()
	a.set_music(false)
	a.start(RATE, RATE, true)
	# Real time, not frames: headless frames take next to no time.
	var deadline: int = Time.get_ticks_msec() + 20_000
	while not a.is_ready() and Time.get_ticks_msec() < deadline:
		await frames(1)
	expect_true(a.is_ready(), "all sounds were synthesised")
	a.now_override_msec = 5000
	a.play("win")
	expect_eq(a.plays, 1)


func test_plays_music_and_stops_when_muted() -> void:
	var a: AudioEngine = make_engine()
	a.render_now(RATE, RATE)
	await frames(1)
	expect_true(a.is_music_playing())
	a.set_intensity(1)
	a.set_music(false)
	expect_false(a.music_enabled)
	expect_false(a.is_music_playing())
	a.set_music(true)
	expect_true(a.is_music_playing())
	a.set_music(false)
