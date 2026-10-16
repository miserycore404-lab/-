class_name DialogueRunner
extends Node
## Plays radio conversations from story_data.gd through the HUD.
## Lines play one after another while the player keeps moving; replies are
## timed, and silence is always an option.

signal finished(id: String)
signal event(name: String)

const Story := preload("res://scripts/data/story_data.gd")

var hud: HUD
var running := false
var current := ""
var _static: AudioStreamPlayer
var _skip := false


func _ready() -> void:
	_static = AudioStreamPlayer.new()
	_static.stream = Sfx.get_stream("radio_static")
	_static.bus = "Voice"
	_static.volume_db = -30.0
	add_child(_static)


func play(id: String) -> void:
	if running:
		await finished
	running = true
	current = id
	var nodes: Array = Story.DIALOGUES[id]
	var labels := {}
	for i in nodes.size():
		var n = nodes[i]
		if n is Dictionary and n.has("label"):
			labels[n["label"]] = i
	var is_radio := id != "ch3_broadcast"
	if is_radio:
		_static.play()
	var i := 0
	var last_speaker := ""
	while i < nodes.size():
		var n = nodes[i]
		i += 1
		if n is Array:
			var sp: String = n[0]
			var text: String = n[1] if Loc.is_ru() else n[2]
			if sp != last_speaker and sp in ["z", "g"]:
				Sfx.play("radio_squelch", -10.0, randf_range(0.95, 1.05), "Voice")
			elif sp == "a" and last_speaker != "a":
				Sfx.play("radio_click", -12.0)
			last_speaker = sp
			var dur := HUD.line_duration(text)
			hud.show_line(sp, text, dur)
			await get_tree().create_timer(dur + 0.35, false).timeout
			continue
		var d: Dictionary = n
		if d.has("label"):
			continue
		if d.has("goto"):
			if d.has("if") and not Game.get_flag(d["if"]):
				continue
			i = labels.get(d["goto"], i)
			continue
		if d.has("set"):
			Game.set_flag(d["set"])
			continue
		if d.has("pause"):
			await get_tree().create_timer(float(d["pause"]), false).timeout
			continue
		if d.has("sfx"):
			Sfx.play(d["sfx"], -6.0)
			continue
		if d.has("event"):
			event.emit(d["event"])
			continue
		if d.has("choice"):
			var opts: Array = d["choice"]
			var texts: Array = []
			for o in opts:
				texts.append(o[0] if Loc.is_ru() else o[1])
			var silence_idx := -1
			if d.has("silence"):
				silence_idx = texts.size()
				texts.append(Loc.t("HUD_SAY_NOTHING"))
			await get_tree().create_timer(0.3, false).timeout
			hud.show_choices(texts, silence_idx, Settings.get_value("timed_choices", true))
			var picked: int = await hud.choice_made
			if picked == silence_idx:
				last_speaker = "a"
				var target: String = d["silence"]
				if target != "":
					i = labels.get(target, i)
				await get_tree().create_timer(0.8, false).timeout
			else:
				var o: Array = opts[picked]
				if o[3] != "":
					Game.set_flag(o[3])
				var said: String = texts[picked]
				last_speaker = "a"
				var dur := HUD.line_duration(said)
				hud.show_line("a", said, dur)
				await get_tree().create_timer(dur + 0.3, false).timeout
				if o[2] != "":
					i = labels.get(o[2], i)
			continue
	if is_radio:
		Sfx.play("radio_squelch", -12.0, 0.9, "Voice")
		_static.stop()
	running = false
	current = ""
	finished.emit(id)
