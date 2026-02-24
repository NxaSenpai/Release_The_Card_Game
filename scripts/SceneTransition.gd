extends CanvasLayer

@onready var color_rect = $ColorRect

var is_transitioning: bool = false

func _ready():
	layer = 100
	color_rect.modulate.a = 0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func transition_seamless(scene_path: String):
	if is_transitioning:
		return
	is_transitioning = true

	var packed = load(scene_path)
	if packed == null:
		push_error("Failed to load scene: " + scene_path)
		is_transitioning = false
		return

	var new_scene = packed.instantiate()
	var root = get_tree().root
	var old_scene = get_tree().current_scene
	root.add_child(new_scene)
	root.move_child(new_scene, old_scene.get_index())
	get_tree().current_scene = new_scene
	return old_scene

func finish_seamless_transition(old_scene: Node):
	if old_scene and is_instance_valid(old_scene):
		old_scene.queue_free()
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false

func transition_with_fade(scene_path: String, duration: float = 0.5):
	if is_transitioning:
		return
	is_transitioning = true

	# Block input during transition
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	color_rect.color = Color(0.02, 0.02, 0.02, 1)
	color_rect.modulate.a = 0

	# --- FADE TO BLACK ---
	var fade_in = create_tween()
	fade_in.tween_property(color_rect, "modulate:a", 1.0, duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_in.finished

	# --- LOAD AND SWITCH SCENE while screen is black ---
	var packed = load(scene_path)
	if packed == null:
		push_error("SceneTransition: Failed to load scene: " + scene_path)
		color_rect.modulate.a = 0
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		is_transitioning = false
		return

	# Change scene properly
	get_tree().change_scene_to_packed(packed)

	# Wait two frames for the new scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame

	# --- FADE FROM BLACK ---
	var fade_out = create_tween()
	fade_out.tween_property(color_rect, "modulate:a", 0.0, duration * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_out.finished

	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
