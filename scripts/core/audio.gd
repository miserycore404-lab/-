extends Node
## Procedural audio: every sound in the game is synthesised here at startup
## (no audio assets), plus a generative piano/pad score that never repeats.

const SR := 22050

var _cache := {}
var _mutex := Mutex.new()
var _warm_thread: Thread
var _interior := false
var _rng := RandomNumberGenerator.new()

# music
var _music_players: Array[AudioStreamPlayer] = []
var _music_idx := 0
var _pad_players: Array[AudioStreamPlayer] = []
var _mood := ""
var _beat_time := 0.0
var _beat := 0
var _bar := 0
var _last_melody := 62
var _music_gain := 1.0
var _music_ready := false

const MOODS := {
	# root midi, chord progression as scale-degree triads (semitone offsets), bpm, melody density
	"menu": {"bpm": 52.0, "density": 0.38, "prog": [[2, 5, 9], [-2, 2, 5], [5, 9, 12], [0, 4, 7], [2, 5, 9], [-5, -2, 2], [-2, 2, 5], [-3, 1, 4]], "root": 50, "pad": 0.55},
	"evening": {"bpm": 58.0, "density": 0.3, "prog": [[5, 9, 12], [2, 5, 9], [-2, 2, 5], [0, 4, 7]], "root": 50, "pad": 0.45},
	"morning": {"bpm": 66.0, "density": 0.45, "prog": [[0, 4, 7], [-3, 0, 4], [5, 9, 12], [7, 11, 14]], "root": 53, "pad": 0.35},
	"night": {"bpm": 46.0, "density": 0.22, "prog": [[2, 5, 9], [-3, 1, 4], [-2, 2, 5], [-3, 1, 4]], "root": 50, "pad": 0.6},
	"letter": {"bpm": 40.0, "density": 0.5, "prog": [[5, 9, 12], [0, 4, 7], [2, 5, 9], [-2, 2, 5]], "root": 50, "pad": 0.7},
	"ending": {"bpm": 50.0, "density": 0.42, "prog": [[5, 9, 12], [0, 4, 7], [-2, 2, 5], [5, 9, 12], [2, 5, 9], [-2, 2, 5], [0, 4, 7], [0, 4, 7]], "root": 53, "pad": 0.6},
}
const SCALE_MINOR := [0, 2, 3, 5, 7, 8, 10]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1991
	_setup_buses()
	Settings.apply_all()
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music_players.append(p)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80
		add_child(p)
		_pad_players.append(p)
	_warm_thread = Thread.new()
	_warm_thread.start(_warm_all)


func _exit_tree() -> void:
	if _warm_thread and _warm_thread.is_started():
		_warm_thread.wait_to_finish()


func _warm_all() -> void:
	for n in ["piano_lo", "piano_mid", "piano_hi", "pad"]:
		get_stream(n)
	_music_ready = true
	for n in ["ui_hover", "ui_click", "ui_back", "wind", "step_snow_0", "step_snow_1", "step_snow_2", "step_snow_3",
			"step_wood_0", "step_wood_1", "step_wood_2", "fire", "radio_squelch", "radio_click", "page",
			"door_open", "door_close", "match", "sip", "pickup", "clock_tick", "bird_0", "bird_1", "bird_2",
			"train_horn", "train_rails", "radio_static", "kettle", "thud", "typewriter", "heartbeat", "wood_drop"]:
		get_stream(n)


# --- buses --------------------------------------------------------------------

func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "Ambience", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var music := AudioServer.get_bus_index("Music")
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.85
	rv.damping = 0.6
	rv.wet = 0.38
	rv.dry = 0.85
	rv.spread = 0.9
	AudioServer.add_bus_effect(music, rv)
	var mlp := AudioEffectLowPassFilter.new()
	mlp.cutoff_hz = 5200
	AudioServer.add_bus_effect(music, mlp)

	var sfx := AudioServer.get_bus_index("SFX")
	var room := AudioEffectReverb.new()
	room.room_size = 0.25
	room.damping = 0.8
	room.wet = 0.18
	room.dry = 1.0
	AudioServer.add_bus_effect(sfx, room)
	AudioServer.set_bus_effect_enabled(sfx, 0, false)

	var amb := AudioServer.get_bus_index("Ambience")
	var alp := AudioEffectLowPassFilter.new()
	alp.cutoff_hz = 700
	AudioServer.add_bus_effect(amb, alp)
	AudioServer.set_bus_effect_enabled(amb, 0, false)

	# Radio voice chain: band-limited, slightly overdriven.
	var voice := AudioServer.get_bus_index("Voice")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 380
	AudioServer.add_bus_effect(voice, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 3200
	AudioServer.add_bus_effect(voice, lp)
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_CLIP
	dist.drive = 0.25
	dist.post_gain = -3
	AudioServer.add_bus_effect(voice, dist)


## Inside the cabin: wind is muffled, footsteps get a small wooden room.
func set_interior(inside: bool) -> void:
	if inside == _interior:
		return
	_interior = inside
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Ambience"), 0, inside)
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("SFX"), 0, inside)


# --- playback -------------------------------------------------------------------

func play(sound: String, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = get_stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func play_ui(sound: String, volume_db := -6.0) -> void:
	play(sound, volume_db, _rng.randf_range(0.96, 1.04))


func play_3d(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, bus := "SFX", max_dist := 40.0) -> AudioStreamPlayer3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = get_stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.max_distance = max_dist
	p.unit_size = 4.0
	scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


func make_loop_3d(sound: String, parent: Node3D, volume_db := 0.0, bus := "Ambience", unit_size := 3.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = get_stream(sound)
	p.volume_db = volume_db
	p.bus = bus
	p.unit_size = unit_size
	p.max_distance = 60.0
	parent.add_child(p)
	return p


func get_stream(sound: String) -> AudioStreamWAV:
	_mutex.lock()
	var s: AudioStreamWAV = _cache.get(sound)
	_mutex.unlock()
	if s:
		return s
	s = _generate(sound)
	_mutex.lock()
	if not _cache.has(sound):
		_cache[sound] = s
	s = _cache[sound]
	_mutex.unlock()
	return s


# --- generative music -----------------------------------------------------------

func set_music_mood(mood: String, fade := 3.0) -> void:
	if mood == _mood:
		return
	_mood = mood
	_beat = 0
	_bar = 0
	_beat_time = 0.0
	var t := create_tween()
	if mood == "":
		t.tween_property(self, "_music_gain", 0.0, fade)
		for p in _pad_players:
			t.parallel().tween_property(p, "volume_db", -80.0, fade)
	else:
		_music_gain = maxf(_music_gain, 0.01)
		t.tween_property(self, "_music_gain", 1.0, fade)


func _process(delta: float) -> void:
	if _mood == "" or not _music_ready:
		return
	var m: Dictionary = MOODS[_mood]
	var beat_len := 60.0 / float(m["bpm"])
	_beat_time += delta
	while _beat_time >= beat_len:
		_beat_time -= beat_len
		_on_beat(m, beat_len)


func _on_beat(m: Dictionary, beat_len: float) -> void:
	var prog: Array = m["prog"]
	var chord: Array = prog[_bar % prog.size()]
	var root: int = m["root"]
	var b := _beat % 4
	if b == 0:
		# bass + pad chord
		_note(root - 12 + int(chord[0]), 0.33, 0.0)
		_pad_chord(root, chord, beat_len * 4.0, float(m["pad"]))
		if _rng.randf() < 0.6:
			_note(root + int(chord[1]), 0.18, beat_len * 0.5)
	elif b == 2 and _rng.randf() < 0.7:
		_note(root - 12 + int(chord[2]), 0.18, 0.0)
	# melody: a slow random walk over the minor scale, gravitating to chord tones
	if _rng.randf() < float(m["density"]):
		var target := root + 12 + int(chord[_rng.randi() % 3])
		var step := _rng.randi_range(-2, 2)
		var cand := _snap_scale(_last_melody + step, root)
		if _rng.randf() < 0.45:
			cand = target
		cand = clampi(cand, root + 7, root + 26)
		_last_melody = cand
		var vel := _rng.randf_range(0.22, 0.42)
		_note(cand, vel, _rng.randf_range(0.0, 0.08))
		if _rng.randf() < 0.25:
			_note(_snap_scale(cand - 2, root), vel * 0.7, beat_len * 0.5)
	_beat += 1
	if _beat % 4 == 0:
		_bar += 1


func _snap_scale(n: int, root: int) -> int:
	var rel := posmod(n - root, 12)
	var best := 0
	var bd := 99
	for s in SCALE_MINOR:
		var d := absi(s - rel)
		if d < bd:
			bd = d
			best = s
	return n - rel + best


func _note(midi: int, vel: float, delay: float) -> void:
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_note.bind(midi, vel, 0.0))
		return
	var base := 57 # A3
	var sample := "piano_mid"
	if midi < 50:
		base = 45
		sample = "piano_lo"
	elif midi >= 66:
		base = 69
		sample = "piano_hi"
	var p := _music_players[_music_idx]
	_music_idx = (_music_idx + 1) % _music_players.size()
	p.stream = get_stream(sample)
	p.pitch_scale = pow(2.0, float(midi - base) / 12.0)
	p.volume_db = linear_to_db(maxf(vel * _music_gain, 0.0001)) - 2.0
	p.play()


func _pad_chord(root: int, chord: Array, dur: float, level: float) -> void:
	for i in 3:
		var p := _pad_players[i]
		var midi := root + int(chord[i])
		var t := create_tween()
		t.tween_property(p, "volume_db", -60.0, 0.6)
		t.tween_callback(func():
			p.stream = get_stream("pad")
			p.pitch_scale = pow(2.0, float(midi - 57) / 12.0)
			p.play(_rng.randf() * 1.5))
		t.tween_property(p, "volume_db", linear_to_db(maxf(level * 0.16 * _music_gain, 0.0001)), dur * 0.35)


# --- synthesis --------------------------------------------------------------------

func _generate(sound: String) -> AudioStreamWAV:
	var r := RandomNumberGenerator.new()
	r.seed = hash(sound)
	var parts := sound.split("_")
	match parts[0]:
		"piano":
			var f := 110.0 if parts[1] == "lo" else (220.0 if parts[1] == "mid" else 440.0)
			return _wav(_piano(f, 5.0 if parts[1] == "lo" else 4.0, r))
		"pad":
			return _wav(_pad(220.0, r), true)
		"step":
			return _wav(_step_snow(r) if parts[1] == "snow" else _step_wood(r))
		"ui":
			return _wav(_ui(parts[1], r))
		"wind":
			return _wav(_wind(r), true)
		"fire":
			return _wav(_fire(r), true)
		"radio":
			if parts[1] == "static":
				return _wav(_radio_static(r), true)
			return _wav(_squelch(r, parts[1] == "click"))
		"page":
			return _wav(_page(r))
		"door":
			return _wav(_creak(r) if parts[1] == "open" else _thud(r, 0.7))
		"thud":
			return _wav(_thud(r, 0.5))
		"wood":
			return _wav(_wood_drop(r))
		"match":
			return _wav(_match(r))
		"sip":
			return _wav(_sip(r))
		"pickup":
			return _wav(_pickup(r))
		"clock":
			return _wav(_tick(r))
		"bird":
			return _wav(_bird(r, int(parts[1])))
		"train":
			return _wav(_horn(r) if parts[1] == "horn" else _rails(r), parts[1] == "rails")
		"kettle":
			return _wav(_kettle(r), true)
		"typewriter":
			return _wav(_typewriter(r))
		"heartbeat":
			return _wav(_heartbeat(r))
		"ring":
			return _wav(_ring())
		"whistle":
			return _wav(_whistle())
	push_warning("Unknown sound " + sound)
	return _wav(PackedFloat32Array([0.0]))


func _wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var n := buf.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * SR))
	b.fill(0.0)
	return b


static func _lowpass(b: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * fc / SR)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = y
	return b


static func _highpass(b: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * fc / SR)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = b[i] - y
	return b


static func _bandpass(b: PackedFloat32Array, fc: float, q: float) -> PackedFloat32Array:
	var w0 := TAU * fc / SR
	var alpha := sin(w0) / (2.0 * q)
	var a0 := 1.0 + alpha
	var b0 := alpha / a0
	var b2 := -alpha / a0
	var a1 := -2.0 * cos(w0) / a0
	var a2 := (1.0 - alpha) / a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in b.size():
		var x := b[i]
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		b[i] = y
	return b


static func _normalize(b: PackedFloat32Array, peak := 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var g := peak / m
	for i in b.size():
		b[i] *= g
	return b


## Make a buffer loop seamlessly by crossfading its tail into its head.
static func _loopify(b: PackedFloat32Array, fade_s: float) -> PackedFloat32Array:
	var f := int(fade_s * SR)
	var n := b.size() - f
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = b[i]
	for i in f:
		var k := float(i) / f
		out[i] = b[i] * k + b[n + i] * (1.0 - k)
	return out


func _piano(f: float, dur: float, r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(dur)
	var n := b.size()
	var harmonics := 7
	for h in range(1, harmonics + 1):
		var fh := f * h * sqrt(1.0 + 0.00035 * h * h)
		var amp := 1.0 / pow(h, 1.35)
		var dec := 0.55 + 0.42 * h + f / 600.0
		var ph := r.randf() * TAU
		var w := TAU * fh / SR
		var detune := TAU * fh * 1.0012 / SR
		for i in n:
			var t := float(i) / SR
			var e := amp * exp(-t * dec)
			if e < 0.0004:
				break
			var s := sin(w * i + ph)
			if h <= 3:
				s = 0.6 * s + 0.4 * sin(detune * i + ph * 1.7)
			b[i] += e * s
	# felt hammer thump
	for i in mini(n, int(0.03 * SR)):
		var t := float(i) / SR
		b[i] += (r.randf() * 2.0 - 1.0) * 0.12 * exp(-t * 160.0)
	for i in mini(n, int(0.006 * SR)):
		b[i] *= float(i) / (0.006 * SR)
	_lowpass(b, 3800.0)
	return _normalize(b, 0.8)


func _pad(f: float, r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(4.0)
	var n := b.size()
	var detunes := [0.996, 1.0, 1.0045, 2.002]
	for d in detunes:
		var ph := r.randf()
		var inc: float = f * float(d) / SR
		var amp: float = 0.35 if float(d) < 2.0 else 0.12
		for i in n:
			ph += inc
			ph -= floor(ph)
			# soft triangle-ish wave: warmer than a saw
			b[i] += amp * (absf(ph * 4.0 - 2.0) - 1.0)
	_lowpass(b, 900.0)
	_lowpass(b, 1400.0)
	# gentle breath
	for i in n:
		b[i] *= 0.85 + 0.15 * sin(TAU * i / n * 2.0)
	return _normalize(b, 0.7)


func _step_snow(r: RandomNumberGenerator) -> PackedFloat32Array:
	# Cold snow squeaks: a dense train of tiny grains with a low compressive thump.
	var b := _buf(0.32)
	var n := b.size()
	var i := 0
	while i < n:
		var t := float(i) / n
		var env := pow(sin(PI * minf(t * 1.25, 1.0)), 0.8)
		var g := r.randf_range(0.2, 1.0) * env
		var glen := r.randi_range(8, 30)
		for k in glen:
			if i + k < n:
				b[i + k] += g * (r.randf() * 2.0 - 1.0) * exp(-k / 6.0)
		i += r.randi_range(10, 70)
	_bandpass(b, r.randf_range(1800.0, 2600.0), 0.9)
	var thump := _buf(0.32)
	for j in n:
		var t := float(j) / SR
		thump[j] = (r.randf() * 2.0 - 1.0) * exp(-t * 28.0) * 0.6
	_lowpass(thump, 260.0)
	for j in n:
		b[j] = b[j] * 1.4 + thump[j] * 2.5
	return _normalize(b, 0.7)


func _step_wood(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.35)
	var n := b.size()
	var f := r.randf_range(90.0, 120.0)
	for i in n:
		var t := float(i) / SR
		b[i] = sin(TAU * f * t) * exp(-t * 22.0) * 0.8 + (r.randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.5
	_lowpass(b, 1200.0)
	# occasional creak of an old floorboard
	if r.randf() < 0.5:
		var c := _creak_core(r, 0.25, r.randf_range(380.0, 520.0))
		for i in mini(n, c.size()):
			b[i] += c[i] * 0.15
	return _normalize(b, 0.6)


func _ui(kind: String, r: RandomNumberGenerator) -> PackedFloat32Array:
	match kind:
		"hover":
			var b := _buf(0.06)
			for i in b.size():
				var t := float(i) / SR
				b[i] = (r.randf() * 2.0 - 1.0) * exp(-t * 260.0) + sin(TAU * 2400.0 * t) * exp(-t * 120.0) * 0.3
			_bandpass(b, 3000.0, 1.2)
			return _normalize(b, 0.4)
		"click":
			return _typewriter(r)
		_:
			var b := _buf(0.12)
			for i in b.size():
				var t := float(i) / SR
				b[i] = (r.randf() * 2.0 - 1.0) * exp(-t * 120.0) * 0.6 + sin(TAU * 160.0 * t) * exp(-t * 40.0)
			_lowpass(b, 2000.0)
			return _normalize(b, 0.5)


func _typewriter(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.14)
	for i in b.size():
		var t := float(i) / SR
		b[i] = (r.randf() * 2.0 - 1.0) * (exp(-t * 300.0) + 0.5 * exp(-absf(t - 0.018) * 700.0))
		b[i] += sin(TAU * 1250.0 * t) * exp(-t * 90.0) * 0.25
	_bandpass(b, 2200.0, 0.7)
	return _normalize(b, 0.55)


func _wind(r: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 12.0
	var b := _buf(dur + 1.5)
	var n := b.size()
	for i in n:
		b[i] = r.randf() * 2.0 - 1.0
	# moving resonance: process in blocks with varying cutoff
	var out := _buf(dur + 1.5)
	var y1 := 0.0
	var y2 := 0.0
	var lfo_ph := r.randf() * TAU
	for i in n:
		var t := float(i) / SR
		var gust := 0.5 + 0.3 * sin(t * 0.55 + lfo_ph) + 0.2 * sin(t * 1.37 + lfo_ph * 2.0)
		var fc := 180.0 + 520.0 * gust
		var a := 1.0 - exp(-TAU * fc / SR)
		y1 += a * (b[i] - y1)
		y2 += a * (y1 - y2)
		out[i] = y2 * (0.35 + 0.65 * gust)
	# high whistle through the trees
	var hiss := _buf(dur + 1.5)
	for i in n:
		hiss[i] = (r.randf() * 2.0 - 1.0)
	_bandpass(hiss, 1400.0, 2.5)
	for i in n:
		var t := float(i) / SR
		out[i] += hiss[i] * 0.05 * (0.5 + 0.5 * sin(t * 0.8 + 1.0))
	return _normalize(_loopify(out, 1.5), 0.6)


func _fire(r: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 6.0
	var b := _buf(dur + 0.5)
	var n := b.size()
	var y := 0.0
	for i in n:
		y += 0.02 * ((r.randf() * 2.0 - 1.0) - y * 0.02)
		b[i] = y * 0.6
	_lowpass(b, 300.0)
	# crackles
	var crack := _buf(dur + 0.5)
	var i := 0
	while i < n:
		var amp := r.randf_range(0.2, 1.0)
		var ln := r.randi_range(20, 220)
		for k in ln:
			if i + k < n:
				crack[i + k] += amp * (r.randf() * 2.0 - 1.0) * exp(-k / (ln * 0.25))
		i += r.randi_range(300, 4000)
	_highpass(crack, 900.0)
	for j in n:
		b[j] = b[j] * 3.0 + crack[j] * 0.8
	return _normalize(_loopify(b, 0.5), 0.6)


func _radio_static(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(3.5)
	var n := b.size()
	for i in n:
		var t := float(i) / SR
		b[i] = (r.randf() * 2.0 - 1.0) * (0.7 + 0.3 * sin(t * 3.0)) + sin(TAU * 50.0 * t) * 0.15
	_bandpass(b, 1600.0, 0.6)
	return _normalize(_loopify(b, 0.5), 0.35)


func _squelch(r: RandomNumberGenerator, click_only: bool) -> PackedFloat32Array:
	var b := _buf(0.12 if click_only else 0.38)
	var n := b.size()
	for i in n:
		var t := float(i) / SR
		var e := exp(-t * 14.0) if not click_only else exp(-t * 60.0)
		b[i] = (r.randf() * 2.0 - 1.0) * e
		if i < 120:
			b[i] += 0.8 * (1.0 if i < 40 else -0.5)
	_bandpass(b, 1900.0, 0.8)
	return _normalize(b, 0.5)


func _page(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.5)
	var n := b.size()
	for i in n:
		var t := float(i) / n
		var env := pow(sin(PI * t), 2.0) * (0.6 + 0.4 * sin(t * 40.0 + r.randf()))
		b[i] = (r.randf() * 2.0 - 1.0) * env
	_bandpass(b, 3500.0, 0.6)
	return _normalize(b, 0.45)


func _creak_core(r: RandomNumberGenerator, dur: float, f0: float) -> PackedFloat32Array:
	# stick-slip friction: an irregular pulse train with a resonant body
	var b := _buf(dur)
	var n := b.size()
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := f0 * (0.8 + 0.4 * sin(t * PI * 1.3) + 0.05 * (r.randf() - 0.5))
		ph += f / SR
		if ph >= 1.0:
			ph -= 1.0
			b[i] = r.randf_range(0.5, 1.0)
	_bandpass(b, f0 * 2.2, 3.0)
	for i in n:
		var t := float(i) / n
		b[i] *= sin(PI * t)
	return b


func _creak(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _creak_core(r, 1.3, 260.0)
	var c := _creak_core(r, 1.3, 410.0)
	for i in b.size():
		b[i] += c[i] * 0.6
	return _normalize(b, 0.5)


func _thud(r: RandomNumberGenerator, weight: float) -> PackedFloat32Array:
	var b := _buf(0.6)
	for i in b.size():
		var t := float(i) / SR
		b[i] = sin(TAU * (70.0 + 40.0 * weight) * t * (1.0 - t * 0.5)) * exp(-t * 12.0) + (r.randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.6
	_lowpass(b, 900.0)
	return _normalize(b, 0.75)


func _wood_drop(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.9)
	for hit in 4:
		var start := int((0.05 + hit * r.randf_range(0.08, 0.18)) * SR)
		var f := r.randf_range(240.0, 420.0)
		for i in range(start, b.size()):
			var t := float(i - start) / SR
			b[i] += (sin(TAU * f * t) * 0.6 + (r.randf() * 2.0 - 1.0) * 0.4) * exp(-t * 30.0) * (1.0 - hit * 0.2)
	_lowpass(b, 2500.0)
	return _normalize(b, 0.7)


func _match(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(1.3)
	var n := b.size()
	for i in n:
		var t := float(i) / SR
		var scrape := (r.randf() * 2.0 - 1.0) * (exp(-absf(t - 0.12) * 25.0))
		var flare := (r.randf() * 2.0 - 1.0) * (smoothstep(0.15, 0.25, t) * exp(-(t - 0.25) * 3.0)) * 0.6
		b[i] = scrape + flare
	_bandpass(b, 2200.0, 0.5)
	return _normalize(b, 0.55)


func _sip(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.9)
	var n := b.size()
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var env := sin(PI * minf(t * 1.6, 1.0)) * (0.7 + 0.3 * sin(t * 90.0))
		y += 0.3 * ((r.randf() * 2.0 - 1.0) - y)
		b[i] = y * env
	_bandpass(b, 900.0, 1.5)
	# swallow
	for i in range(int(0.65 * SR), n):
		var t := float(i) / SR - 0.65
		b[i] += sin(TAU * 120.0 * t) * exp(-t * 25.0) * 0.6
	return _normalize(b, 0.4)


func _pickup(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.25)
	for i in b.size():
		var t := float(i) / SR
		b[i] = (r.randf() * 2.0 - 1.0) * exp(-t * 50.0) * 0.6 + sin(TAU * 520.0 * t) * exp(-t * 30.0) * 0.4
	_lowpass(b, 3000.0)
	return _normalize(b, 0.4)


func _tick(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.08)
	for i in b.size():
		var t := float(i) / SR
		b[i] = (r.randf() * 2.0 - 1.0) * exp(-t * 400.0) + sin(TAU * 1800.0 * t) * exp(-t * 200.0) * 0.5
	_bandpass(b, 2500.0, 1.5)
	return _normalize(b, 0.4)


func _bird(r: RandomNumberGenerator, variant: int) -> PackedFloat32Array:
	# Bullfinch: soft, melancholy piping "pyu... pyu"
	var b := _buf(0.9)
	var n := b.size()
	var notes := 1 + variant % 2
	for k in notes:
		var start := k * 0.38
		var f0 := r.randf_range(1650.0, 1900.0) + variant * 60.0
		var ph := 0.0
		for i in range(int(start * SR), mini(n, int((start + 0.24) * SR))):
			var t := float(i) / SR - start
			var u := t / 0.24
			var f := f0 * (1.08 - 0.22 * u) + 30.0 * sin(t * 90.0)
			ph += TAU * f / SR
			var env := sin(PI * u) * sin(PI * u)
			b[i] += sin(ph) * env + 0.15 * sin(ph * 2.0) * env
	return _normalize(b, 0.4)


func _horn(r: RandomNumberGenerator) -> PackedFloat32Array:
	# Electric-train tifon: two detuned reedy tones.
	var b := _buf(2.6)
	var n := b.size()
	var freqs := [311.0, 370.0]
	for f in freqs:
		var ph := 0.0
		for i in n:
			var t := float(i) / SR
			ph += f * (1.0 + 0.003 * sin(t * 30.0)) / SR
			ph -= floor(ph)
			var env := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(2.0, 2.55, t))
			b[i] += (ph * 2.0 - 1.0) * env * 0.4
	_lowpass(b, 1800.0)
	_lowpass(b, 2400.0)
	return _normalize(b, 0.8)


func _rails(r: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 2.4
	var b := _buf(dur)
	var n := b.size()
	# rumble
	var y := 0.0
	for i in n:
		y += 0.05 * ((r.randf() * 2.0 - 1.0) - y)
		b[i] = y * 1.5
	_lowpass(b, 160.0)
	# clack-clack of wheel bogies over rail joints
	for hit in [0.0, 0.14, 1.2, 1.34]:
		var s := int(hit * SR)
		for i in range(s, mini(n, s + int(0.12 * SR))):
			var t := float(i - s) / SR
			b[i] += (sin(TAU * 180.0 * t) + (r.randf() * 2.0 - 1.0) * 0.6) * exp(-t * 35.0) * 0.7
	return _normalize(b, 0.7)


func _kettle(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(3.0)
	var n := b.size()
	for i in n:
		b[i] = r.randf() * 2.0 - 1.0
	_bandpass(b, 700.0, 1.2)
	var bub := _buf(3.0)
	var i := 0
	while i < n:
		var f := r.randf_range(400.0, 900.0)
		for k in 200:
			if i + k < n:
				bub[i + k] += sin(TAU * f * k / SR * (1.0 + k / 400.0)) * exp(-k / 60.0) * 0.5
		i += r.randi_range(200, 1500)
	for j in n:
		b[j] = b[j] * 0.4 + bub[j]
	return _normalize(_loopify(b, 0.4), 0.4)


func _heartbeat(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(1.0)
	for hit in [0.0, 0.22]:
		var s := int(hit * SR)
		for i in range(s, b.size()):
			var t := float(i - s) / SR
			b[i] += sin(TAU * 55.0 * t) * exp(-t * 18.0) * (1.0 if hit == 0.0 else 0.7)
	return _normalize(b, 0.8)


func _ring() -> PackedFloat32Array:
	# Soviet long-distance ringback: 425 Hz, one second on.
	var b := _buf(1.4)
	for i in b.size():
		var t := float(i) / SR
		var env := smoothstep(0.0, 0.02, t) * (1.0 - smoothstep(1.0, 1.05, t))
		b[i] = sin(TAU * 425.0 * t) * env * 0.5
	_bandpass(b, 600.0, 0.7)
	return _normalize(b, 0.5)


func _whistle() -> PackedFloat32Array:
	# A man imitating a bullfinch: two soft descending notes, breathy.
	var b := _buf(1.3)
	var ph := 0.0
	for k in 2:
		var start := 0.05 + k * 0.55
		for i in range(int(start * SR), mini(b.size(), int((start + 0.42) * SR))):
			var t := float(i) / SR - start
			var u := t / 0.42
			var f := 1450.0 - 300.0 * u - k * 60.0 + 12.0 * sin(t * 40.0)
			ph += TAU * f / SR
			var env := sin(PI * u)
			b[i] += sin(ph) * env * 0.8 + (randf() * 2.0 - 1.0) * env * 0.05
	return _normalize(b, 0.5)
