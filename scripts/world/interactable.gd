class_name Interactable
extends Area3D
## Anything the player can use. The player's ray hits these (layer 2);
## using one notifies every node in the "interact_listeners" group.

signal used(it: Interactable)

const LAYER := 2

var id := ""
var prompt: Variant = "" # {ru, en} dictionary or translation key
var enabled := true
var max_distance := 2.4
## Optional: node the hand reaches toward when used.
var hand_target: Node3D


static func make(parent: Node3D, p_id: String, p_prompt: Variant, size: Vector3, pos: Vector3, rot_y := 0.0) -> Interactable:
	var it := Interactable.new()
	it.name = "I_" + p_id
	it.id = p_id
	it.prompt = p_prompt
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	it.add_child(cs)
	it.position = pos
	it.rotation.y = rot_y
	parent.add_child(it)
	return it


func _ready() -> void:
	collision_layer = 1 << (LAYER - 1)
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactables")


func get_prompt() -> String:
	return Loc.pick(prompt)


func set_prompt(p: Variant) -> void:
	prompt = p


func use() -> void:
	if not enabled:
		return
	used.emit(self)
	get_tree().call_group("interact_listeners", "on_interact", id, self)
