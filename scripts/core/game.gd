extends Node
## Story state, checkpoints and top-level flow between scenes.

signal flag_changed(flag: String, value: Variant)

const SAVE_PATH := "user://save.cfg"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const PROLOGUE_SCENE := "res://scenes/prologue.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const CHAPTER_COUNT := 3

var chapter := 1
var flags := {}
var found_docs: Array = []
var chapter_reached := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_meta()


func set_flag(f: String, v: Variant = true) -> void:
	flags[f] = v
	flag_changed.emit(f, v)


func get_flag(f: String, default: Variant = false) -> Variant:
	return flags.get(f, default)


func add_doc(id: String) -> bool:
	if id in found_docs:
		return false
	found_docs.append(id)
	return true


# --- flow ---------------------------------------------------------------------

func new_game() -> void:
	chapter = 1
	flags = {}
	found_docs = []
	Fader.change_scene(PROLOGUE_SCENE, 1.2, 2.0)


func start_chapter(n: int) -> void:
	chapter = n
	chapter_reached = maxi(chapter_reached, n)
	save_checkpoint()
	Fader.change_scene(GAME_SCENE, 1.0, 0.1)


func continue_game() -> void:
	if not load_checkpoint():
		new_game()
		return
	Fader.change_scene(GAME_SCENE, 1.0, 0.1)


func to_menu() -> void:
	Sfx.set_music_mood("", 1.0)
	Fader.change_scene(MENU_SCENE, 1.0, 1.6)


# --- persistence ----------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_checkpoint() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "chapter", chapter)
	cf.set_value("game", "flags", flags)
	cf.set_value("game", "docs", found_docs)
	cf.set_value("game", "reached", chapter_reached)
	cf.set_value("game", "time", Time.get_datetime_string_from_system())
	cf.save(SAVE_PATH)


func load_checkpoint() -> bool:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return false
	chapter = cf.get_value("game", "chapter", 1)
	flags = cf.get_value("game", "flags", {})
	found_docs = cf.get_value("game", "docs", [])
	chapter_reached = cf.get_value("game", "reached", chapter)
	return true


func _load_meta() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		chapter = cf.get_value("game", "chapter", 1)
		chapter_reached = cf.get_value("game", "reached", chapter)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	chapter_reached = 0
