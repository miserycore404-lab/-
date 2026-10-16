extends Node
## In-game scene root: world, player, HUD, story director and pause menu.

const Story := preload("res://scripts/data/story_data.gd")

var world: World
var player: Player
var hud: HUD
var director: Director
var pause_menu: PauseMenu


func _ready() -> void:
	get_tree().paused = false
	world = World.new()
	world.preset_name = Story.CHAPTERS[Game.chapter]["preset"]
	add_child(world)
	player = Player.new()
	player.name = "Player"
	player.world = world
	add_child(player)
	world.follow(player)
	hud = HUD.new()
	hud.player = player
	add_child(hud)
	player.focus_changed.connect(hud.set_focus)
	director = Director.new()
	director.world = world
	director.player = player
	director.hud = hud
	add_child(director)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	director.start(Game.chapter)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and pause_menu == null:
		if hud.reader_open or hud.card.visible:
			return
		if hud.notebook_open:
			hud.toggle_notebook()
			return
		open_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_menu == null and is_inside_tree() and not Engine.is_editor_hint():
		if hud and not hud.card.visible and DisplayServer.get_name() != "headless":
			open_pause()


func open_pause() -> void:
	pause_menu = PauseMenu.new()
	pause_menu.hud = hud
	add_child(pause_menu)
	pause_menu.closed.connect(func(): pause_menu = null)
