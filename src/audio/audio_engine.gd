class_name AudioEngine
extends Node
## Procedural sound effects and music (autoload "Audio"). Every sound is
## synthesised at startup by SoundBank (on a worker thread where available,
## otherwise a few milliseconds per frame), so the game ships no audio files.
## Sounds requested before they are ready are skipped.

## Minimum time between two plays of the same sound (ms), so 20 guns don't deafen you.
const THROTTLE_MS: Dictionary[String, int] = {
	"gun": 45, "hit": 35, "missile": 70, "cannon": 60, "zap": 90, "frost": 120, "pop": 30, "explode": 50, "heal": 200,
}
const SFX_RATE: int = 44100
const MUSIC_RATE: int = 22050
const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"
const MASTER_GAIN: float = 0.8
const MUSIC_GAIN: float = 0.5
const POLYPHONY: int = 8
## Time budget per frame when rendering on the main thread.
const FRAME_BUDGET_MS: int = 4

var sfx_enabled: bool = true
var music_enabled: bool = true
## How many sounds were started (for tests).
var plays: int = 0
## Replaces the clock used for throttling when >= 0 (for tests).
var now_override_msec: int = -1

var _players: Dictionary[String, AudioStreamPlayer] = {}
var _calm: AudioStreamPlayer
var _drums: AudioStreamPlayer
var _intensity: int = 0
var _last: Dictionary[String, int] = {}
var _jobs: Array[Callable] = []
var _jobs_lock := Mutex.new()
var _task: int = -1
var _music_ready: bool = false
var _drum_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	# Nothing to hear without an audio device (e.g. headless runs).
	if AudioServer.get_driver_name() != "Dummy":
		start()


## Queues the synthesis of every sound. With `threaded` (and thread support),
## a worker thread renders them; otherwise _process does, a little per frame.
func start(sfx_rate: int = SFX_RATE, music_rate: int = MUSIC_RATE, threaded: bool = true) -> void:
	if not _jobs.is_empty() or _task >= 0:
		return
	for name: String in SoundBank.SFX_NAMES:
		_jobs.append(_render_sfx.bind(name, sfx_rate))
	var layers: Array[Synth] = SoundBank.music_buffers(music_rate)
	for step: int in SoundBank.MUSIC_STEPS:
		_jobs.append(SoundBank.render_music_step.bind(layers[0], layers[1], step))
	_jobs.append(_finish_music.bind(layers[0], layers[1]))
	if threaded and OS.has_feature("threads"):
		_task = WorkerThreadPool.add_task(_run_all_jobs, false, "Synthesise sounds")


## Renders everything right now (tests).
func render_now(sfx_rate: int, music_rate: int) -> void:
	start(sfx_rate, music_rate, false)
	while _run_job():
		pass


func is_ready() -> bool:
	return _players.size() == SoundBank.SFX_NAMES.size() and _music_ready


func _process(_delta: float) -> void:
	if _task >= 0 or _jobs.is_empty():
		return
	var until: int = Time.get_ticks_msec() + FRAME_BUDGET_MS
	while Time.get_ticks_msec() < until and _run_job():
		pass


func _exit_tree() -> void:
	if _task >= 0:
		_jobs_lock.lock()
		_jobs.clear() # the worker stops after its current job
		_jobs_lock.unlock()
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _run_all_jobs() -> void:
	while _run_job():
		pass


## Runs the next job; false when there was none.
func _run_job() -> bool:
	_jobs_lock.lock()
	var job: Callable = _jobs.pop_front() if not _jobs.is_empty() else Callable()
	_jobs_lock.unlock()
	if not job.is_valid():
		return false
	job.call()
	return true


func _render_sfx(name: String, rate: int) -> void:
	_install_sfx.call_deferred(name, SoundBank.render_sfx(name, rate).to_stream())


func _finish_music(calm: Synth, drums: Synth) -> void:
	_install_music.call_deferred(calm.to_stream(), drums.to_stream())


func _install_sfx(name: String, stream: AudioStreamWAV) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS
	player.max_polyphony = POLYPHONY
	add_child(player)
	_players[name] = player


func _install_music(calm: AudioStreamWAV, drums: AudioStreamWAV) -> void:
	_calm = AudioStreamPlayer.new()
	_calm.stream = calm
	_calm.bus = MUSIC_BUS
	add_child(_calm)
	_drums = AudioStreamPlayer.new()
	_drums.stream = drums
	_drums.bus = MUSIC_BUS
	_drums.volume_linear = 1.0 if _intensity > 0 else 0.0
	add_child(_drums)
	_music_ready = true
	if music_enabled:
		_start_music()
	if _task >= 0:
		# The music is the last job: the worker is done (or just returning).
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _setup_buses() -> void:
	for bus: StringName in [SFX_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(SFX_BUS), MASTER_GAIN)
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(MUSIC_BUS), MASTER_GAIN * MUSIC_GAIN)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not sfx_enabled)


func set_sfx(on: bool) -> void:
	sfx_enabled = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not on)


func set_music(on: bool) -> void:
	music_enabled = on
	if on:
		_start_music()
	else:
		_stop_music()


## 0 = calm, 1 = a wave is in progress (the drums join in).
func set_intensity(level: int) -> void:
	if level == _intensity:
		return
	_intensity = level
	if _drums == null:
		return
	if _drum_tween != null:
		_drum_tween.kill()
	_drum_tween = create_tween()
	_drum_tween.tween_property(_drums, "volume_linear", 1.0 if level > 0 else 0.0, 0.15)


func is_music_playing() -> bool:
	return _calm != null and _calm.playing


func play(name: String) -> void:
	if not sfx_enabled or not _players.has(name):
		return
	var now: int = now_override_msec if now_override_msec >= 0 else Time.get_ticks_msec()
	var gap: int = THROTTLE_MS.get(name, 0)
	if gap > 0 and _last.has(name) and now - _last[name] < gap:
		return
	_last[name] = now
	_players[name].play()
	plays += 1


func _start_music() -> void:
	if not _music_ready or _calm.playing:
		return
	# Both layers loop over the same length, so they stay in sync.
	_calm.play()
	_drums.play()


func _stop_music() -> void:
	if not _music_ready:
		return
	_calm.stop()
	_drums.stop()
