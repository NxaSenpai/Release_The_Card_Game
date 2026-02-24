extends Control
class_name CardUI

var rank_name: String
var suit_name: String
var value: int
var is_selected: bool = false

# Tween references to prevent stacking
var _hover_tween: Tween = null
var _bg_glow_tween: Tween = null
var _select_tween: Tween = null
var _select_pop_tween: Tween = null

@onready var bg = $Background

func setup(p_rank: int, p_suit: String):
	suit_name = p_suit
	value = min(p_rank, 10)
	
	rank_name = str(p_rank)
	if p_rank == 1: rank_name = "A"
	elif p_rank == 11: rank_name = "J"
	elif p_rank == 12: rank_name = "Q"
	elif p_rank == 13: rank_name = "K"
	
	if bg == null:
		bg = get_node("Background")
	
	var file_path = "res://textures/card_background/card" + suit_name + rank_name + ".png"
	
	if FileAccess.file_exists(file_path):
		bg.texture = load(file_path)
	else:
		print("CRITICAL ERROR: Filename not found: ", file_path)

func _ready():
	pivot_offset = size / 2
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var main_node = get_tree().current_scene
		
		if main_node.has_method("is_card_clickable") and main_node.is_card_clickable(self):
			toggle_selection()
			
			if main_node.has_method("shake_screen"):
				main_node.shake_screen(3.0)
			if main_node.has_method("glitch_effect"):
				main_node.glitch_effect(0.3)
			
			if main_node.has_node("SfxSelect"):
				main_node.get_node("SfxSelect").play()
			
			main_node.check_selection()
		else:
			play_error_shake()
			
			if main_node.has_method("shake_screen"):
				main_node.shake_screen(5.0)
			if main_node.has_method("glitch_effect"):
				main_node.glitch_effect(0.6)
			if main_node.has_method("flash_screen"):
				main_node.flash_screen(Color(1, 0.2, 0.1, 0.15), 0.1)
			if main_node.has_node("SfxError"):
				main_node.get_node("SfxError").play()

func toggle_selection():
	is_selected = !is_selected
	
	if bg == null: bg = $Background
	
	# Kill any existing selection tweens
	if _select_tween and _select_tween.is_valid():
		_select_tween.kill()
	if _select_pop_tween and _select_pop_tween.is_valid():
		_select_pop_tween.kill()
	if _bg_glow_tween and _bg_glow_tween.is_valid():
		_bg_glow_tween.kill()
	
	if is_selected:
		_select_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_select_tween.tween_property(bg, "position:y", -30, 0.2)
		
		_bg_glow_tween = create_tween()
		_bg_glow_tween.tween_property(bg, "modulate", Color(1.15, 1.15, 0.85), 0.15)
		
		_select_pop_tween = create_tween()
		_select_pop_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.06)
		_select_pop_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK)
	else:
		_select_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_select_tween.tween_property(bg, "position:y", 0, 0.2)
		
		_bg_glow_tween = create_tween()
		_bg_glow_tween.tween_property(bg, "modulate", Color.WHITE, 0.15)
		
		_select_pop_tween = create_tween()
		_select_pop_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
		_select_pop_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_BACK)

func play_error_shake():
	if bg == null: bg = $Background
	
	# Kill glow tween so it doesn't fight
	if _bg_glow_tween and _bg_glow_tween.is_valid():
		_bg_glow_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(bg, "position:x", 12, 0.04)
	tween.tween_property(bg, "position:x", -12, 0.04)
	tween.tween_property(bg, "position:x", 8, 0.04)
	tween.tween_property(bg, "position:x", -8, 0.04)
	tween.tween_property(bg, "position:x", 3, 0.03)
	tween.tween_property(bg, "position:x", 0, 0.03)
	
	_bg_glow_tween = create_tween()
	_bg_glow_tween.tween_property(bg, "modulate", Color(1.5, 0.4, 0.4, 1), 0.05)
	_bg_glow_tween.tween_property(bg, "modulate", Color.WHITE, 0.2)

# --- HOVER EFFECTS ---
func _on_mouse_entered():
	# Kill previous hover tween to prevent stacking
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	
	var target_scale = Vector2(1.08, 1.08) if not is_selected else Vector2(1.05, 1.05)
	_hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target_scale, 0.12)
	
	# Subtle brightness on hover (only if not selected — selected has its own glow)
	if bg and not is_selected:
		if _bg_glow_tween and _bg_glow_tween.is_valid():
			_bg_glow_tween.kill()
		_bg_glow_tween = create_tween()
		_bg_glow_tween.tween_property(bg, "modulate", Color(1.1, 1.1, 1.05, 1), 0.1)

func _on_mouse_exited():
	# Kill previous hover tween
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	
	_hover_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Reset brightness (only if not selected)
	if bg and not is_selected:
		if _bg_glow_tween and _bg_glow_tween.is_valid():
			_bg_glow_tween.kill()
		_bg_glow_tween = create_tween()
		_bg_glow_tween.tween_property(bg, "modulate", Color.WHITE, 0.1)
