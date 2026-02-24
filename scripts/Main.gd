extends Control

# --- VARIABLES ---
var deck: Array = []
var score: int = 0
var suits = ["Diamonds", "Clubs", "Hearts", "Spades"]
var can_draw: bool = true 
var target_score: int = 0
var combo_count: int = 0
var cards_drawn_this_game: int = 0
var restart_button_visible: bool = false
var is_first_start: bool = true
var is_paused: bool = false

var bgm_themes = [
	preload("res://background_music/Aylex - Last Summer (freetouse.com).mp3"),
	preload("res://background_music/Limujii - November (freetouse.com).mp3"),
	preload("res://background_music/Lukrembo - Donut (freetouse.com).mp3"),
	preload("res://background_music/Moavii - Foreign (freetouse.com).mp3")
]
var current_bgm_index: int = -1

@onready var custom_font = preload("res://fonts/Unitblock-JpJma.ttf")
@onready var card_scene = preload("res://scenes/card.tscn")
@onready var hand_container = $Hand
@onready var background_layer = $BackgroundLayer
@onready var ui_layer = $UILayer

const CARD_WIDTH = 120 
const MAX_HAND_WIDTH = 800 
const DEFAULT_GAP = 30

# Juice settings
var screen_shake_intensity: float = 0.0
var original_position: Vector2
var releasing_cards: Array = []

# Glitch shader
var glitch_rect: ColorRect
var glitch_material: ShaderMaterial
var glitch_shader = preload("res://shaders/glitch.gdshader")

# CRT ambient shader
var crt_rect: ColorRect
var crt_material: ShaderMaterial
var crt_shader = preload("res://shaders/crt.gdshader")

# Background shader material reference
var bg_shader_material: ShaderMaterial = null
var _bg_color_tween: Tween = null

# Color themes for random background on restart
var color_themes: Array = [
	{  # Ocean Blue
		"dark": Color(0.04, 0.32, 0.55, 1),
		"light": Color(0.06, 0.47, 0.60, 1),
		"refraction": Color(0.96, 0.98, 0.86, 1),
		"shaft": Color(0.88, 0.90, 0.78, 1)
	},
	{  # Emerald Green
		"dark": Color(0.04, 0.35, 0.18, 1),
		"light": Color(0.08, 0.55, 0.30, 1),
		"refraction": Color(0.80, 0.98, 0.75, 1),
		"shaft": Color(0.70, 0.92, 0.65, 1)
	},
	{  # Crimson Red
		"dark": Color(0.40, 0.08, 0.08, 1),
		"light": Color(0.60, 0.15, 0.12, 1),
		"refraction": Color(1.0, 0.85, 0.75, 1),
		"shaft": Color(0.95, 0.75, 0.65, 1)
	},
	{  # Royal Purple
		"dark": Color(0.15, 0.05, 0.35, 1),
		"light": Color(0.30, 0.10, 0.55, 1),
		"refraction": Color(0.70, 0.50, 0.90, 1),
		"shaft": Color(0.60, 0.40, 0.80, 1)
	},
	{  # Sunset Orange
		"dark": Color(0.45, 0.18, 0.05, 1),
		"light": Color(0.65, 0.30, 0.08, 1),
		"refraction": Color(1.0, 0.90, 0.60, 1),
		"shaft": Color(0.95, 0.80, 0.50, 1)
	},
	{  # Deep Teal
		"dark": Color(0.02, 0.25, 0.30, 1),
		"light": Color(0.05, 0.40, 0.45, 1),
		"refraction": Color(0.75, 0.95, 0.90, 1),
		"shaft": Color(0.65, 0.88, 0.82, 1)
	},
	{  # Golden Amber
		"dark": Color(0.35, 0.25, 0.05, 1),
		"light": Color(0.55, 0.40, 0.10, 1),
		"refraction": Color(1.0, 0.95, 0.70, 1),
		"shaft": Color(0.95, 0.88, 0.55, 1)
	},
	{  # Midnight Blue
		"dark": Color(0.03, 0.05, 0.25, 1),
		"light": Color(0.08, 0.12, 0.45, 1),
		"refraction": Color(0.70, 0.75, 0.95, 1),
		"shaft": Color(0.60, 0.65, 0.88, 1)
	},
]
var current_theme_index: int = -1

# --- SETTINGS (loaded from GameSettings autoload) ---
func get_crt_enabled() -> bool:
	return GameSettings.crt_enabled if Engine.has_singleton("GameSettings") or get_node_or_null("/root/GameSettings") else true

func get_glitch_enabled() -> bool:
	return GameSettings.glitch_enabled if get_node_or_null("/root/GameSettings") else true

func get_glitch_intensity() -> float:
	return GameSettings.glitch_intensity if get_node_or_null("/root/GameSettings") else 1.0

# --- INITIALIZATION ---
func _ready():
	original_position = position
	setup_glitch_shader()
	setup_crt_shader()
	setup_bg_shader()
	_apply_display_to_scene()
	animate_intro()
	start_new_game()
	setup_music()
	start_background_animation()

# NEW: called on _ready to apply saved display settings inside the game scene
func _apply_display_to_scene():
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		return

	# Apply display mode & window size (in case user launched directly into game)
	gs.apply_display_settings()

	# Update CRT resolution uniform to match actual window size
	var win_size = Vector2(DisplayServer.window_get_size())
	if crt_material:
		crt_material.set_shader_parameter("resolution", win_size)

	# Apply CRT visibility
	if crt_rect:
		crt_rect.visible = gs.crt_enabled

	# Apply glitch visibility
	if glitch_rect:
		glitch_rect.visible = gs.glitch_enabled

	# Apply music volume
	if has_node("MusicPlayer"):
		var vol = gs.music_volume
		$MusicPlayer.volume_db = linear_to_db(vol) if vol > 0.0 else -80.0

func _process(delta):
	if screen_shake_intensity > 0:
		position = original_position + Vector2(
			randf_range(-screen_shake_intensity, screen_shake_intensity),
			randf_range(-screen_shake_intensity * 0.5, screen_shake_intensity * 0.5)
		)
		screen_shake_intensity = lerp(screen_shake_intensity, 0.0, delta * 10)
	else:
		position = original_position

# --- GLITCH SHADER ---
func setup_glitch_shader():
	var canvas = CanvasLayer.new()
	canvas.name = "GlitchCanvas"
	canvas.layer = 10
	add_child(canvas)

	glitch_rect = ColorRect.new()
	glitch_rect.name = "GlitchRect"
	glitch_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	glitch_material = ShaderMaterial.new()
	glitch_material.shader = glitch_shader
	glitch_material.set_shader_parameter("shake_power", 0.01)
	glitch_material.set_shader_parameter("shake_rate", 0.0)
	glitch_material.set_shader_parameter("shake_speed", 3.0)
	glitch_material.set_shader_parameter("shake_block_size", 30.5)
	glitch_material.set_shader_parameter("shake_color_rate", 0.003)

	glitch_rect.material = glitch_material
	canvas.add_child(glitch_rect)

# --- CRT SHADER ---
func setup_crt_shader():
	var canvas = CanvasLayer.new()
	canvas.name = "CRTCanvas"
	canvas.layer = 9
	add_child(canvas)

	crt_rect = ColorRect.new()
	crt_rect.name = "CRTRect"
	crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	crt_material = ShaderMaterial.new()
	crt_material.shader = crt_shader

	crt_material.set_shader_parameter("overlay", false)
	crt_material.set_shader_parameter("scanlines_opacity", 0.08)
	crt_material.set_shader_parameter("scanlines_width", 0.25)
	crt_material.set_shader_parameter("grille_opacity", 0.03)
	crt_material.set_shader_parameter("resolution", Vector2(1152.0, 648.0))
	crt_material.set_shader_parameter("pixelate", false)
	crt_material.set_shader_parameter("roll", true)
	crt_material.set_shader_parameter("roll_speed", 0.8)
	crt_material.set_shader_parameter("roll_size", 5.0)
	crt_material.set_shader_parameter("roll_variation", 1.8)
	crt_material.set_shader_parameter("distort_intensity", 0.001)
	crt_material.set_shader_parameter("noise_opacity", 0.02)
	crt_material.set_shader_parameter("noise_speed", 2.0)
	crt_material.set_shader_parameter("static_noise_intensity", 0.008)
	crt_material.set_shader_parameter("aberration", 0.005)
	crt_material.set_shader_parameter("brightness", 1.02)
	crt_material.set_shader_parameter("discolor", false)
	crt_material.set_shader_parameter("warp_amount", 0.2)
	crt_material.set_shader_parameter("clip_warp", false)
	crt_material.set_shader_parameter("vignette_intensity", 0.2)
	crt_material.set_shader_parameter("vignette_opacity", 0.25)

	crt_rect.material = crt_material
	canvas.add_child(crt_rect)

	apply_crt_setting()

func apply_crt_setting():
	if crt_rect:
		var enabled = get_node_or_null("/root/GameSettings").crt_enabled if get_node_or_null("/root/GameSettings") else true
		crt_rect.visible = enabled

# --- BACKGROUND SHADER ---
func setup_bg_shader():
	if has_node("BackgroundLayer/AnimatedBG"):
		var bg = $BackgroundLayer/AnimatedBG
		if bg.material is ShaderMaterial:
			bg_shader_material = bg.material

func transition_bg_color(theme: Dictionary, duration: float = 1.5):
	if bg_shader_material == null:
		return

	# Kill previous color transition
	if _bg_color_tween and _bg_color_tween.is_valid():
		_bg_color_tween.kill()

	# Copy current colors into the base uniforms (so we blend FROM them)
	# The current visual is at whatever blend was — bake it
	var current_blend = bg_shader_material.get_shader_parameter("color_blend")
	if current_blend > 0.0:
		var cur_dark = bg_shader_material.get_shader_parameter("sea_color_dark")
		var cur_light = bg_shader_material.get_shader_parameter("sea_color_light")
		var cur_refr = bg_shader_material.get_shader_parameter("refraction_color")
		var cur_shaft = bg_shader_material.get_shader_parameter("light_shaft_color")
		var tgt_dark = bg_shader_material.get_shader_parameter("target_sea_color_dark")
		var tgt_light = bg_shader_material.get_shader_parameter("target_sea_color_light")
		var tgt_refr = bg_shader_material.get_shader_parameter("target_refraction_color")
		var tgt_shaft = bg_shader_material.get_shader_parameter("target_light_shaft_color")

		# Bake the interpolated color as the new base
		bg_shader_material.set_shader_parameter("sea_color_dark", cur_dark.lerp(tgt_dark, current_blend))
		bg_shader_material.set_shader_parameter("sea_color_light", cur_light.lerp(tgt_light, current_blend))
		bg_shader_material.set_shader_parameter("refraction_color", cur_refr.lerp(tgt_refr, current_blend))
		bg_shader_material.set_shader_parameter("light_shaft_color", cur_shaft.lerp(tgt_shaft, current_blend))

	# Set new target colors
	bg_shader_material.set_shader_parameter("target_sea_color_dark", theme["dark"])
	bg_shader_material.set_shader_parameter("target_sea_color_light", theme["light"])
	bg_shader_material.set_shader_parameter("target_refraction_color", theme["refraction"])
	bg_shader_material.set_shader_parameter("target_light_shaft_color", theme["shaft"])
	bg_shader_material.set_shader_parameter("color_blend", 0.0)

	# Smoothly animate blend from 0 to 1
	_bg_color_tween = create_tween()
	_bg_color_tween.tween_method(
		func(val: float):
			if bg_shader_material:
				bg_shader_material.set_shader_parameter("color_blend", val),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func pick_random_theme() -> Dictionary:
	var new_index = randi() % color_themes.size()
	if color_themes.size() > 1:
		while new_index == current_theme_index:
			new_index = randi() % color_themes.size()
	current_theme_index = new_index
	return color_themes[current_theme_index]

# --- FUNCTIONS ---
func animate_intro():
	modulate.a = 1.0
	
	if has_node("UILayer"):
		for child in $UILayer.get_children():
			if child.name == "RestartButton":
				child.modulate.a = 0
				child.scale = Vector2(0.8, 0.8)
				child.disabled = true
				continue
			if child.name == "DrawButton":
				child.modulate.a = 0
				child.disabled = true
				continue
			var original_pos = child.position
			child.position.y -= 50
			child.modulate.a = 0
			var delay = randf_range(0.3, 0.8)
			var ui_tween = create_tween().set_parallel(true)
			ui_tween.tween_property(child, "position:y", original_pos.y, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
			ui_tween.tween_property(child, "modulate:a", 1.0, 0.4).set_delay(delay)
	
	if has_node("Hand"):
		$Hand.modulate.a = 0
		var hand_tween = create_tween()
		hand_tween.tween_property($Hand, "modulate:a", 1.0, 0.5).set_delay(0.4).set_trans(Tween.TRANS_SINE)

func start_background_animation():
	if has_node("AmbientParticles"):
		$AmbientParticles.emitting = true


func start_new_game():
	combo_count = 0
	cards_drawn_this_game = 0
	restart_button_visible = false
	can_draw = false
	
	# Transition to a random color theme
	var theme = pick_random_theme()
	if is_first_start:
		# On first start, set colors instantly (no transition from nothing)
		if bg_shader_material:
			bg_shader_material.set_shader_parameter("sea_color_dark", theme["dark"])
			bg_shader_material.set_shader_parameter("sea_color_light", theme["light"])
			bg_shader_material.set_shader_parameter("refraction_color", theme["refraction"])
			bg_shader_material.set_shader_parameter("light_shaft_color", theme["shaft"])
			bg_shader_material.set_shader_parameter("target_sea_color_dark", theme["dark"])
			bg_shader_material.set_shader_parameter("target_sea_color_light", theme["light"])
			bg_shader_material.set_shader_parameter("target_refraction_color", theme["refraction"])
			bg_shader_material.set_shader_parameter("target_light_shaft_color", theme["shaft"])
			bg_shader_material.set_shader_parameter("color_blend", 0.0)
	else:
		transition_bg_color(theme, 2.0)
	
	# Hide draw button during cleanup
	if has_node("UILayer/DrawButton"):
		var draw_btn = $UILayer/DrawButton
		draw_btn.disabled = true
		if not is_first_start:
			var hide_draw = create_tween()
			hide_draw.tween_property(draw_btn, "modulate:a", 0.3, 0.1)
	
	# Hide restart button at start
	if has_node("UILayer/RestartButton"):
		var btn = $UILayer/RestartButton
		btn.disabled = true
		var hide_tween = create_tween().set_parallel(true)
		hide_tween.tween_property(btn, "modulate:a", 0.0, 0.2)
		hide_tween.tween_property(btn, "scale", Vector2(0.8, 0.8), 0.2)
	
	# Cleanup Win Labels
	for child in get_children():
		if child is Label and child.text.contains("WIN"):
			var exit_tween = create_tween()
			exit_tween.tween_property(child, "scale", Vector2(1.5, 1.5), 0.3)
			exit_tween.parallel().tween_property(child, "modulate:a", 0, 0.3)
			exit_tween.tween_callback(child.queue_free)
	
	releasing_cards.clear()
	
	# --- Cards fly away ALL AT ONCE ---
	var children = hand_container.get_children()
	var has_cards = children.size() > 0
	
	for child in children:
		child.z_index = 10
		var global_pos = child.global_position
		hand_container.remove_child(child)
		add_child(child)
		child.global_position = global_pos
		
		var fly = create_tween().set_parallel(true)
		fly.tween_property(child, "position:y", -400, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		fly.tween_property(child, "position:x", child.position.x + randf_range(-150, 150), 0.35).set_trans(Tween.TRANS_SINE)
		fly.tween_property(child, "rotation_degrees", randf_range(-50, 50), 0.35)
		fly.tween_property(child, "scale", Vector2(0.4, 0.4), 0.35).set_trans(Tween.TRANS_QUAD)
		fly.tween_property(child, "modulate:a", 0.0, 0.25).set_delay(0.05)
		fly.tween_callback(child.queue_free).set_delay(0.4)
	
	score = 0
	target_score = 0
	create_deck()
	update_ui()
	
	if has_cards:
		flash_screen(Color(1, 1, 1, 0.2), 0.15)
		await get_tree().create_timer(0.4).timeout
	elif is_first_start:
		await get_tree().create_timer(0.6).timeout
	
	is_first_start = false
	
	# Show draw button
	can_draw = true
	if has_node("UILayer/DrawButton"):
		var draw_btn = $UILayer/DrawButton
		draw_btn.disabled = false
		draw_btn.pivot_offset = draw_btn.size / 2
		var show_draw = create_tween().set_parallel(true)
		show_draw.tween_property(draw_btn, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
		show_draw.tween_property(draw_btn, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func reveal_restart_button():
	if not has_node("UILayer/RestartButton"):
		return
	if restart_button_visible:
		return
	restart_button_visible = true
	
	var btn = $UILayer/RestartButton
	btn.disabled = false
	btn.pivot_offset = btn.size / 2
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func create_deck():
	deck.clear()
	for s in suits:
		for r in range(1, 14):
			deck.append({"rank": r, "suit": s})
		deck.shuffle()

func update_ui():
	if has_node("UILayer/DeckLabel"): 
		$UILayer/DeckLabel.text = "Cards: " + str(deck.size())
		if deck.size() <= 10 and deck.size() > 0:
			pulse_label($UILayer/DeckLabel, Color.ORANGE)
	if has_node("UILayer/ScoreLabel"): 
		target_score = score
		$UILayer/ScoreLabel.text = "Score: " + str(score)

func pulse_label(label: Label, color: Color):
	var original_color = label.modulate
	label.pivot_offset = label.size / 2
	var tween = create_tween()
	tween.tween_property(label, "modulate", color, 0.1)
	tween.tween_property(label, "modulate", original_color, 0.15)
	tween.parallel().tween_property(label, "scale", Vector2(1.1, 1.1), 0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)

# --- MUSIC ---
func setup_music():
	if not has_node("MusicPlayer"):
		return
	if bgm_themes.size() == 0:
		return
	
	$MusicPlayer.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Apply saved volume
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		var vol = gs.music_volume
		$MusicPlayer.volume_db = linear_to_db(vol) if vol > 0.0 else -80.0
	
	if not $MusicPlayer.finished.is_connected(_on_music_finished):
		$MusicPlayer.finished.connect(_on_music_finished)
	
	play_next_bgm()

func play_next_bgm():
	if not has_node("MusicPlayer") or bgm_themes.size() == 0:
		return
	
	var new_index = randi() % bgm_themes.size()
	if bgm_themes.size() > 1:
		while new_index == current_bgm_index:
			new_index = randi() % bgm_themes.size()
	
	current_bgm_index = new_index
	$MusicPlayer.stream = bgm_themes[current_bgm_index]
	$MusicPlayer.play()

func _on_music_finished():
	play_next_bgm()

func format_number(num: int) -> String:
	var str_num = str(abs(num))
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		result = str_num[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "," + result
	if num < 0:
		result = "-" + result
	return result

# --- SCREEN EFFECTS ---
func shake_screen(intensity: float = 10.0):
	var gs = get_node_or_null("/root/GameSettings")
	if gs and not gs.screen_shake_enabled:
		return
	var gs_scale = gs.screen_shake_intensity if gs else 1.0
	screen_shake_intensity = max(screen_shake_intensity, intensity * gs_scale)

func flash_screen(color: Color, duration: float = 0.1):
	if has_node("FlashOverlay"):
		$FlashOverlay.color = color
		$FlashOverlay.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property($FlashOverlay, "modulate:a", 0.0, duration)

func spawn_particles_at(pos: Vector2, color: Color = Color.GOLD):
	if has_node("SuccessParticles"):
		$SuccessParticles.position = pos
		$SuccessParticles.modulate = color
		$SuccessParticles.restart()

func glitch_effect(intensity: float = 1.0):
	var gs = get_node_or_null("/root/GameSettings")
	if gs and not gs.glitch_enabled:
		return
	var gs_scale = gs.glitch_intensity if gs else 1.0
	intensity *= gs_scale

	if glitch_material:
		var glitch_rate = clamp(intensity * 0.55, 0.0, 1.0)
		var glitch_power = clamp(intensity * 0.06, 0.0, 0.25)
		var glitch_color_rate = clamp(intensity * 0.025, 0.0, 0.12)
		var glitch_speed = clamp(5.0 + intensity * 8.0, 5.0, 40.0)
		var glitch_block = clamp(30.5 - intensity * 4.0, 8.0, 30.5)

		glitch_material.set_shader_parameter("shake_rate", glitch_rate)
		glitch_material.set_shader_parameter("shake_power", glitch_power)
		glitch_material.set_shader_parameter("shake_color_rate", glitch_color_rate)
		glitch_material.set_shader_parameter("shake_speed", glitch_speed)
		glitch_material.set_shader_parameter("shake_block_size", glitch_block)

		var shader_tween = create_tween()
		shader_tween.tween_interval(0.05 + intensity * 0.03)
		shader_tween.tween_method(
			func(val: float):
				if glitch_material:
					glitch_material.set_shader_parameter("shake_rate", val)
					glitch_material.set_shader_parameter("shake_power", val * 0.11)
					glitch_material.set_shader_parameter("shake_color_rate", val * 0.045)
					glitch_material.set_shader_parameter("shake_speed", 5.0 + val * 15.0)
					glitch_material.set_shader_parameter("shake_block_size", 30.5 - val * 6.0),
			glitch_rate,
			0.0,
			0.25 + intensity * 0.18
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var viewport_size = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1152, 648)

	var strip_count = randi_range(5, 10) if intensity > 1.0 else randi_range(3, 6)
	for i in range(strip_count):
		var strip = ColorRect.new()
		var strip_height = randf_range(2, 10) * intensity
		strip.size = Vector2(viewport_size.x + 60, strip_height)
		strip.position = Vector2(
			randf_range(-40, 10) * intensity,
			randf_range(0, viewport_size.y)
		)
		strip.color = [
			Color(1, 0.1, 0.1, 0.35 * intensity),
			Color(0, 1, 0.6, 0.25 * intensity),
			Color(0.2, 0.3, 1, 0.35 * intensity),
			Color(1, 1, 1, 0.2 * intensity)
		][i % 4]
		strip.z_index = 90
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

		var strip_tween = create_tween().set_parallel(true)
		strip_tween.tween_property(strip, "position:x", strip.position.x + randf_range(-60, 60) * intensity, randf_range(0.03, 0.10))
		strip_tween.tween_property(strip, "modulate:a", 0.0, randf_range(0.06, 0.18))
		strip_tween.tween_callback(strip.queue_free).set_delay(0.2)

	if intensity > 0.4:
		for j in range(randi_range(2, 4)):
			var slice = ColorRect.new()
			var slice_height = randf_range(25, 80) * intensity
			var slice_y = randf_range(0, viewport_size.y - slice_height)
			slice.size = Vector2(viewport_size.x, slice_height)
			slice.position = Vector2(randf_range(-20, 20) * intensity, slice_y)
			slice.color = Color(0, 0, 0, 0.12 * intensity)
			slice.z_index = 89
			slice.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(slice)

			var slice_tween = create_tween()
			slice_tween.tween_property(slice, "position:x", slice.position.x + randf_range(-30, 30) * intensity, 0.04)
			slice_tween.tween_property(slice, "modulate:a", 0.0, 0.07)
			slice_tween.tween_callback(slice.queue_free)

	if intensity > 0.5:
		var red_rect = ColorRect.new()
		red_rect.size = viewport_size
		red_rect.position = Vector2(randf_range(4, 10) * intensity, 0)
		red_rect.color = Color(1, 0, 0, clamp(0.10 * intensity, 0.0, 0.35))
		red_rect.z_index = 88
		red_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(red_rect)

		var blue_rect = ColorRect.new()
		blue_rect.size = viewport_size
		blue_rect.position = Vector2(randf_range(-10, -4) * intensity, randf_range(-3, 3))
		blue_rect.color = Color(0, 0.2, 1, clamp(0.10 * intensity, 0.0, 0.35))
		blue_rect.z_index = 88
		blue_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(blue_rect)

		var rgb_tween = create_tween().set_parallel(true)
		rgb_tween.tween_property(red_rect, "modulate:a", 0.0, 0.10)
		rgb_tween.tween_property(blue_rect, "modulate:a", 0.0, 0.10)
		rgb_tween.tween_callback(red_rect.queue_free).set_delay(0.12)
		rgb_tween.tween_callback(blue_rect.queue_free).set_delay(0.12)

	var jitter_intensity = intensity * 5.0
	var glitch_tween = create_tween()
	glitch_tween.tween_property(self, "position", original_position + Vector2(randf_range(-jitter_intensity, jitter_intensity), randf_range(-jitter_intensity * 0.5, jitter_intensity * 0.5)), 0.02)
	glitch_tween.tween_property(self, "position", original_position + Vector2(randf_range(-jitter_intensity * 0.6, jitter_intensity * 0.6), randf_range(-jitter_intensity * 0.3, jitter_intensity * 0.3)), 0.02)
	glitch_tween.tween_property(self, "position", original_position, 0.03)

func freeze_frame(duration: float = 0.04):
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false

# --- ACTIONS ---
func _on_restart_button_pressed():
	if has_node("UILayer/RestartButton"):
		button_press_effect($UILayer/RestartButton)
		shake_screen(12.0)
		glitch_effect(2.5)
		flash_screen(Color(1, 0.3, 0.1, 0.2), 0.2)
		
		await get_tree().create_timer(0.1).timeout
		start_new_game()

func _on_draw_button_pressed():
	if deck.size() > 0 and can_draw:
		can_draw = false
		cards_drawn_this_game += 1
		
		if has_node("UILayer/DrawButton"):
			button_press_effect($UILayer/DrawButton)
		
		shake_screen(4.0)
		glitch_effect(0.4)
		
		if has_node("SfxDraw"): $SfxDraw.play()
		
		var card_data = deck.pop_back()
		var new_card = card_scene.instantiate()
		
		new_card.modulate.a = 0
		new_card.custom_minimum_size.x = 0 
		new_card.scale = Vector2(0.8, 0.8)
		
		hand_container.add_child(new_card)
		new_card.setup(card_data["rank"], card_data["suit"])
		
		var grow_tween = create_tween().set_parallel(true)
		grow_tween.tween_property(new_card, "custom_minimum_size:x", CARD_WIDTH, 0.3).set_trans(Tween.TRANS_SINE)
		grow_tween.tween_property(new_card, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		update_ui()
		reflow_hand()
		animate_card_entry(new_card)
		
		if cards_drawn_this_game >= 3:
			reveal_restart_button()
		
		await get_tree().create_timer(0.2).timeout
		can_draw = true
	elif deck.size() == 0:
		shake_screen(6.0)
		glitch_effect(2.5)
		flash_screen(Color(1, 0.5, 0, 0.15), 0.15)

func button_press_effect(button: Button):
	button.pivot_offset = button.size / 2
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.85, 0.85), 0.04)
	tween.tween_property(button, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)
	
	var original_modulate = button.modulate
	var flash_tween = create_tween()
	flash_tween.tween_property(button, "modulate", Color(1.4, 1.3, 1.1, 1), 0.05)
	flash_tween.tween_property(button, "modulate", original_modulate, 0.15)

func animate_card_entry(card_node: Control):
	var target_bg = card_node.get_node_or_null("Background")
	if target_bg:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(card_node, "modulate:a", 1.0, 0.2)
		target_bg.position.y = 250
		tween.tween_property(target_bg, "position:y", 0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		await tween.finished
		if is_instance_valid(card_node):
			var glow_tween = create_tween()
			glow_tween.tween_property(card_node, "modulate", Color(1.3, 1.3, 1.3, 1), 0.1)
			glow_tween.tween_property(card_node, "modulate", Color(1, 1, 1, 1), 0.2)

# --- REFLOW ---
func reflow_hand():
	await get_tree().process_frame 
	var active_cards = hand_container.get_children().filter(func(c): return !c.is_queued_for_deletion() and c.visible and c not in releasing_cards)
	var count = active_cards.size()
	if count == 0: return
	
	var total_card_width = count * CARD_WIDTH
	var target_sep = DEFAULT_GAP
	if (total_card_width + (target_sep * (count - 1))) > MAX_HAND_WIDTH:
		target_sep = (MAX_HAND_WIDTH - total_card_width) / float(max(1, count - 1))

	var tween = create_tween()
	tween.tween_method(
		func(val): hand_container.add_theme_constant_override("separation", val),
		hand_container.get_theme_constant("separation"),
		target_sep,
		0.4
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# --- MATCHING & WIN CONDITION ---
func process_match(indices, nodes):
	indices.sort()
	var active_cards = hand_container.get_children().filter(func(c): return !c.is_queued_for_deletion() and c.visible and c not in releasing_cards)
	var hand_size = active_cards.size()
	
	var total_sum = nodes[0].value + nodes[1].value + nodes[2].value
	var is_sum_valid = (total_sum == 10 or total_sum == 20 or total_sum == 30)
	
	var is_edge_valid = false
	if indices == [0, 1, 2]: is_edge_valid = true
	elif indices == [hand_size-3, hand_size-2, hand_size-1]: is_edge_valid = true
	elif indices == [0, 1, hand_size-1]: is_edge_valid = true
	elif indices == [0, hand_size-2, hand_size-1]: is_edge_valid = true
	
	if is_sum_valid and is_edge_valid:
		combo_count += 1
		var combo_multiplier = 1.0 + (combo_count - 1) * 0.1
		var points = int(total_sum * combo_multiplier)
		score += points
		
		for n in nodes:
			releasing_cards.append(n)
		
		await freeze_frame(0.05)
		
		shake_screen(15.0)
		glitch_effect(2.2)
		
		var flash_color = Color(1, 0.8, 0, 0.4) if combo_count > 1 else Color(1, 1, 1, 0.3)
		flash_screen(flash_color, 0.15)
		
		if has_node("SfxMatch"): $SfxMatch.play()
		
		show_floating_text("+" + str(points), nodes[1].global_position, Color.GOLD)
		if combo_count > 1:
			await get_tree().create_timer(0.1).timeout
			show_floating_text("COMBO x" + str(combo_count) + "!", nodes[1].global_position + Vector2(0, -40), Color.ORANGE_RED)
			glitch_effect(3.5)
			shake_screen(22.0)
			flash_screen(Color(1, 0.5, 0, 0.3), 0.2)
		
		var remaining_cards = hand_container.get_children().filter(func(c): return !c.is_queued_for_deletion() and c.visible and c not in releasing_cards)
		var old_positions = {}
		for card in remaining_cards:
			old_positions[card] = card.global_position
		
		for i in range(nodes.size()):
			var n = nodes[i]
			n.is_selected = false
			n.z_index = 10
			
			spawn_particles_at(n.global_position + Vector2(60, 100))
			
			var global_pos = n.global_position
			hand_container.remove_child(n)
			add_child(n)
			n.global_position = global_pos
			
			var rel = create_tween().set_parallel(false)
			rel.tween_property(n, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD)
			rel.tween_property(n, "position:y", n.position.y + 20, 0.08).set_trans(Tween.TRANS_QUAD)
			rel.set_parallel(true)
			rel.tween_property(n, "position:y", -400, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			rel.tween_property(n, "rotation_degrees", randf_range(-45, 45), 0.35)
			rel.tween_property(n, "modulate:a", 0.0, 0.25).set_delay(0.05)
			rel.tween_property(n, "scale", Vector2(0.5, 0.5), 0.35)
		
		await get_tree().process_frame
		
		for card in remaining_cards:
			if is_instance_valid(card) and card in old_positions:
				var new_global_pos = card.global_position
				var offset = old_positions[card] - new_global_pos
				card.position.x += offset.x
				var slide = create_tween()
				slide.tween_property(card, "position:x", card.position.x - offset.x, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		reflow_hand()
		
		await get_tree().create_timer(0.45).timeout
		
		for n in nodes:
			if is_instance_valid(n):
				releasing_cards.erase(n)
				n.queue_free()
		
		update_ui()
		reflow_hand()
		
		await get_tree().create_timer(0.2).timeout
		check_for_win()
	else:
		combo_count = 0
		if has_node("SfxError"): $SfxError.play()
		shake_screen(8.0)
		flash_screen(Color(1, 0, 0, 0.2), 0.1)
		glitch_effect(1.8)
		
		for n in nodes:
			if is_instance_valid(n):
				var wiggle = create_tween()
				wiggle.tween_property(n, "rotation_degrees", 5, 0.05)
				wiggle.tween_property(n, "rotation_degrees", -5, 0.05)
				wiggle.tween_property(n, "rotation_degrees", 3, 0.05)
				wiggle.tween_property(n, "rotation_degrees", -3, 0.05)
				wiggle.tween_property(n, "rotation_degrees", 0, 0.05)
				n.toggle_selection()

func show_floating_text(text: String, pos: Vector2, color: Color = Color.WHITE):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_override("font", custom_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = pos - Vector2(50, 0)
	label.z_index = 100
	label.pivot_offset = Vector2(50, 16)
	add_child(label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 80, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0, 0.8).set_delay(0.4)
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_callback(label.queue_free).set_delay(1.2)

func check_for_win():
	var active_cards = hand_container.get_children().filter(func(c): return !c.is_queued_for_deletion() and c.visible)
	
	if deck.size() == 0 and active_cards.size() == 1:
		show_win_screen("YOU WIN!")

func show_win_screen(message: String):
	flash_screen(Color(1, 0.9, 0.5, 0.6), 0.5)
	shake_screen(25.0)
	glitch_effect(4.0)
	
	if has_node("SuccessParticles"):
		for i in range(5):
			await get_tree().create_timer(0.1).timeout
			$SuccessParticles.position = Vector2(randf_range(200, 900), randf_range(200, 500))
			$SuccessParticles.restart()
			glitch_effect(1.5)
	
	var win_label = Label.new()
	win_label.text = message
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.add_theme_font_size_override("font_size", 72)
	win_label.add_theme_color_override("font_color", Color.GOLD)
	win_label.add_theme_color_override("font_outline_color", Color.BLACK)
	win_label.add_theme_constant_override("outline_size", 8)
	win_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	win_label.z_index = 100
	win_label.pivot_offset = Vector2(100, 36)
	add_child(win_label)
	
	win_label.modulate.a = 0
	win_label.scale = Vector2(0.3, 0.3)
	win_label.position.y -= 50
	
	await freeze_frame(0.08)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(win_label, "modulate:a", 1.0, 0.3)
	tween.tween_property(win_label, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(win_label, "position:y", win_label.position.y + 50, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(win_label, "scale", Vector2(1.25, 1.25), 0.5).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(win_label, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE)

# --- SELECTION HELPERS ---
func check_selection():
	var active_cards = hand_container.get_children().filter(func(c): return !c.is_queued_for_deletion() and c.visible and c not in releasing_cards)
	var selected_nodes = active_cards.filter(func(c): return c.is_selected)
	if selected_nodes.size() == 3:
		var indices = []
		for n in selected_nodes: indices.append(active_cards.find(n))
		process_match(indices, selected_nodes)

func is_card_clickable(card_node: Control) -> bool:
	var active_cards = hand_container.get_children().filter(func(c): return !c.is_queued_for_deletion() and c.visible and c not in releasing_cards)
	var idx = active_cards.find(card_node)
	var total = active_cards.size()
	if total <= 3: return true
	return idx in [0, 1, 2, total-3, total-2, total-1]



# --- PAUSE MENU ---

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if is_paused:
			resume_game()
		else:
			pause_game()

func pause_game():
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	open_pause_menu()

func resume_game():
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
	close_pause_menu()

func open_pause_menu():
	if has_node("PauseMenu"):
		return

	# Dim overlay
	var dim = ColorRect.new()
	dim.name = "PauseDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 150
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dim)

	var dim_tween = dim.create_tween()
	dim_tween.tween_property(dim, "color:a", 0.6, 0.2)

	# Panel container
	var panel = PanelContainer.new()
	panel.name = "PauseMenu"
	panel.z_index = 200
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.12, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.6, 0.2, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_size = 16
	style.shadow_color = Color(0, 0, 0, 0.7)
	panel.add_theme_stylebox_override("panel", style)

	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200.0
	panel.offset_top = -220.0
	panel.offset_right = 200.0
	panel.offset_bottom = 220.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", custom_font)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# Resume button
	var resume_style = StyleBoxFlat.new()
	resume_style.bg_color = Color(0.75, 0.55, 0.1, 1)
	resume_style.border_width_left = 3
	resume_style.border_width_top = 3
	resume_style.border_width_right = 3
	resume_style.border_width_bottom = 3
	resume_style.border_color = Color(1, 0.85, 0.3, 1)
	resume_style.corner_radius_top_left = 8
	resume_style.corner_radius_top_right = 8
	resume_style.corner_radius_bottom_right = 8
	resume_style.corner_radius_bottom_left = 8
	resume_style.shadow_color = Color(0.3, 0.2, 0, 0.6)
	resume_style.shadow_size = 5

	var resume_style_hover = resume_style.duplicate()
	resume_style_hover.bg_color = Color(0.9, 0.7, 0.15, 1)
	resume_style_hover.border_color = Color(1, 0.95, 0.5, 1)
	resume_style_hover.shadow_color = Color(1, 0.8, 0.2, 0.35)
	resume_style_hover.shadow_size = 8

	var resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(280, 60)
	resume_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume_btn.add_theme_font_override("font", custom_font)
	resume_btn.add_theme_font_size_override("font_size", 24)
	resume_btn.add_theme_color_override("font_color", Color(0.08, 0.04, 0, 1))
	resume_btn.add_theme_color_override("font_hover_color", Color(0.04, 0.02, 0, 1))
	resume_btn.add_theme_stylebox_override("normal", resume_style)
	resume_btn.add_theme_stylebox_override("hover", resume_style_hover)
	resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(func():
		button_press_effect(resume_btn)
		await get_tree().create_timer(0.1, true, false, true).timeout
		resume_game()
	)
	vbox.add_child(resume_btn)

	# Main Menu button
	var menu_style = StyleBoxFlat.new()
	menu_style.bg_color = Color(0.12, 0.08, 0.20, 0.9)
	menu_style.border_width_left = 2
	menu_style.border_width_top = 2
	menu_style.border_width_right = 2
	menu_style.border_width_bottom = 2
	menu_style.border_color = Color(0.7, 0.55, 0.2, 0.7)
	menu_style.corner_radius_top_left = 8
	menu_style.corner_radius_top_right = 8
	menu_style.corner_radius_bottom_right = 8
	menu_style.corner_radius_bottom_left = 8
	menu_style.shadow_color = Color(0, 0, 0, 0.3)
	menu_style.shadow_size = 3

	var menu_style_hover = menu_style.duplicate()
	menu_style_hover.bg_color = Color(0.20, 0.14, 0.35, 1)
	menu_style_hover.border_color = Color(0.9, 0.7, 0.3, 1)
	menu_style_hover.shadow_color = Color(0.8, 0.6, 0.2, 0.25)
	menu_style_hover.shadow_size = 6

	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(280, 55)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_btn.add_theme_font_override("font", custom_font)
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55, 0.9))
	menu_btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.6, 1))
	menu_btn.add_theme_stylebox_override("normal", menu_style)
	menu_btn.add_theme_stylebox_override("hover", menu_style_hover)
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.pressed.connect(func():
		button_press_effect(menu_btn)
		shake_screen(6.0)
		glitch_effect(2.0)
		# Unpause before switching scene
		get_tree().paused = false
		is_paused = false
		await get_tree().create_timer(0.12, true, false, true).timeout
		var transition = get_tree().root.get_node_or_null("SceneTransition")
		if transition:
			transition.transition_with_fade("res://scenes/menu.tscn", 0.5)
		else:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
	)
	vbox.add_child(menu_btn)

	add_child(panel)

	# Entrance animation
	panel.modulate.a = 0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(
		(panel.offset_right - panel.offset_left) / 2.0,
		(panel.offset_bottom - panel.offset_top) / 2.0
	)
	var open_tween = panel.create_tween().set_parallel(true)
	open_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	open_tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	open_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close_pause_menu():
	var dim = get_node_or_null("PauseDim")
	var panel = get_node_or_null("PauseMenu")

	if panel and is_instance_valid(panel):
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
		var close_tween = panel.create_tween().set_parallel(true)
		close_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		close_tween.tween_property(panel, "modulate:a", 0.0, 0.15)
		close_tween.tween_property(panel, "scale", Vector2(0.88, 0.88), 0.15)
		close_tween.tween_callback(panel.queue_free).set_delay(0.16)

	if dim and is_instance_valid(dim):
		var dim_tween = dim.create_tween()
		dim_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		dim_tween.tween_property(dim, "color:a", 0.0, 0.15)
		dim_tween.tween_callback(dim.queue_free)
